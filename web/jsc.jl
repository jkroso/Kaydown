# Runs JavaScript with JavaScriptCore, the engine that macOS has for Safari.
# Nothing is added to the app: the engine is part of the system.
#
#     js = Context()                       # a world of JavaScript with its own globals
#     evaluate(js, "1 + 2")                # 3.0
#     js["double"] = x -> 2x               # a Julia function that a script can call
#     evaluate(js, "double(4)")            # 8.0
#     call(js, "double", 5)                # 10.0: call a global function by its name
#     js["answer"]                         # the value of a global
#     close(js)                            # give its memory back. A context that's dropped is closed after Julia frees it.
#
# How values cross:
#
#   Julia to JavaScript    nothing is null, missing is undefined, a number is a number, a string, a symbol or a
#                          character is a string, a vector or a tuple is an array, a dictionary or a named tuple is
#                          an object, a function is a function
#   JavaScript to Julia    null and undefined are nothing, a number is a Float64, an array is a Vector{Any}, and any
#                          other object is an `Object`: `o["name"]` reads a property of it and `o(args...)` calls it
#
# A script that throws makes `evaluate` and `call` throw a `ScriptError`, which
# has the message, the line and the stack. A Julia function that throws while a
# script calls it throws an Error in the script, which the script can catch.
#
# A script that runs for longer than `limit` seconds is stopped, and that's a
# `ScriptError` too. Promises are settled before `evaluate` and `call` return.
#
# One thread at a time may use a context, and only from the main task of that
# thread. JavaScriptCore looks through the thread's stack for the values that a
# script still uses. A task that's made with @async or @spawn has a stack of its
# own, which JavaScriptCore knows nothing of: a script that ran there would end
# the program. So `Context`, `evaluate` and `call` throw an error there.

const LIB = "/System/Library/Frameworks/JavaScriptCore.framework/JavaScriptCore"
const Handle = Ptr{Cvoid}   # a JSValueRef, a JSObjectRef, a JSStringRef or a JSContextRef

"What a script threw"
struct ScriptError <: Exception
  message::String     # as the script would print it: "TypeError: x is not a function"
  file::String        # the name that its script was given
  line::Int           # 0 when it isn't known
  stack::String
end
Base.showerror(io::IO, e::ScriptError) = begin
  print(io, "ScriptError: ", e.message)
  e.line > 0 && print(io, " (", isempty(e.file) ? "line " : e.file * ":", e.line, ")")
  isempty(e.stack) || print(io, "\n", e.stack)
end

"A world of JavaScript"
mutable struct Context
  ref::Handle                     # the JSGlobalContextRef, or C_NULL once it's closed
  natives::Dict{Handle,Any}       # the Julia function behind each function that was made for a script
end

"An object of a script. It's kept alive for as long as Julia holds this."
mutable struct Object
  context::Context
  ref::Handle
  Object(c::Context, ref::Handle) = begin
    protect(c, ref)
    finalizer(o -> isopen(o.context) && drop(o.context.ref, o.ref), new(c, ref))
  end
end

# JavaScriptCore frees a value that no script can reach, and it can't see what Julia holds. It does look through the
# stack, so a value in a local variable is safe. A value that's kept in a Julia array or a Ref is kept alive with these.
protect(c::Context, v::Handle) = ccall((:JSValueProtect, LIB), Cvoid, (Handle, Handle), c.ref, v)
unprotect(c::Context, v::Handle) = ccall((:JSValueUnprotect, LIB), Cvoid, (Handle, Handle), c.ref, v)

# Each open context by its JSGlobalContextRef, so that a call from a script finds its Julia functions
const CONTEXTS = Dict{Handle,WeakRef}()

# Julia frees a context or an object that nothing holds in whichever task and thread its own memory manager runs, which
# is no place to call JavaScriptCore from. So what's freed is only noted here: a context, with C_NULL, or a value of a
# context. The next call from the main task gives each back to JavaScriptCore.
const DROPPED = Tuple{Handle,Handle}[]
const DROPPING = Threads.SpinLock()

drop(context::Handle, value::Handle) = begin
  lock(DROPPING)
  push!(DROPPED, (context, value))
  unlock(DROPPING)
  nothing
end

"Give back to JavaScriptCore what Julia has freed"
release_dropped() = begin
  isempty(DROPPED) && return
  lock(DROPPING)
  dropped = copy(DROPPED)
  empty!(DROPPED)
  unlock(DROPPING)
  for (context, value) in dropped
    haskey(CONTEXTS, context) || continue   # its context is closed already, and its values went with it
    if value == C_NULL
      delete!(CONTEXTS, context)
      ccall((:JSGlobalContextRelease, LIB), Cvoid, (Handle,), context)
    else
      ccall((:JSValueUnprotect, LIB), Cvoid, (Handle, Handle), context, value)
    end
  end
end

# The pointers that JavaScriptCore calls Julia through: `called` for a script's call, and `stop` for a script that ran too long
const CALLED = Ref{Ptr{Cvoid}}(C_NULL)
const STOP = Ref{Ptr{Cvoid}}(C_NULL)

"""
A new world of JavaScript. A script in it that runs for longer than `limit`
seconds is stopped. With `limit=nothing`, a script can run for ever.
"""
Context(; limit=10) = begin
  guard()
  # Each context gets a group of its own, which holds its memory, so that closing the context frees all of it.
  # JSGlobalContextCreate would put every context of this program in one group that's never freed: it does that for a
  # program that wasn't built against JavaScriptCore, as Julia's isn't.
  group = ccall((:JSContextGroupCreate, LIB), Handle, ())
  ref = ccall((:JSGlobalContextCreateInGroup, LIB), Handle, (Handle, Handle), group, C_NULL)
  ccall((:JSContextGroupRelease, LIB), Cvoid, (Handle,), group)
  c = finalizer(c -> isopen(c) && drop(c.ref, C_NULL), Context(ref, Dict{Handle,Any}()))
  CONTEXTS[ref] = WeakRef(c)
  limit === nothing || limit!(c, limit)
  c
end

Base.isopen(c::Context) = c.ref != C_NULL

Base.close(c::Context) = begin
  isopen(c) || return
  guard()
  ref = c.ref
  c.ref = C_NULL
  delete!(CONTEXTS, ref)
  empty!(c.natives)
  ccall((:JSGlobalContextRelease, LIB), Cvoid, (Handle,), ref)
  nothing
end

stop(::Handle, ::Ptr{Cvoid})::Bool = true

"Stop a script of `c` that runs for longer than `seconds`. JavaScriptCore has this, but not in its public headers, so it's used only when it's there."
limit!(c::Context, seconds) = begin
  lib = Base.Libc.Libdl.dlopen(LIB)
  set = Base.Libc.Libdl.dlsym(lib, :JSContextGroupSetExecutionTimeLimit; throw_error=false)
  set === nothing && return false
  group = ccall((:JSContextGetGroup, LIB), Handle, (Handle,), c.ref)
  ccall(set, Cvoid, (Handle, Cdouble, Ptr{Cvoid}, Ptr{Cvoid}), group, Float64(seconds), STOP[], C_NULL)
  true
end

"""
Call the script's function `f` with a promise and its reason each time a
promise fails and no script takes the failure. JavaScriptCore has this, but
not in its public headers, so it's used only when it's there.
"""
unhandled!(c::Context, f::Object) = begin
  set = Base.Libc.Libdl.dlsym(Base.Libc.Libdl.dlopen(LIB), :JSGlobalContextSetUnhandledRejectionCallback; throw_error=false)
  set === nothing && return false
  ccall(set, Cvoid, (Handle, Handle, Ptr{Handle}), c.ref, f.ref, C_NULL)
  true
end

# --- where a script may run ---------------------------------------------------------------

"Where the stack of the code that's running has got to"
frame() = Base.llvmcall(("""
  declare ptr @llvm.frameaddress.p0(i32)
  define i64 @frame() {
    %1 = call ptr @llvm.frameaddress.p0(i32 0)
    %2 = ptrtoint ptr %1 to i64
    ret i64 %2
  }""", "frame"), UInt, Tuple{})

"True when the code that's running is on the stack that its thread started with, which is where JavaScriptCore looks"
athome() = begin
  thread = ccall(:pthread_self, Ptr{Cvoid}, ())
  top = UInt(ccall(:pthread_get_stackaddr_np, Ptr{Cvoid}, (Ptr{Cvoid},), thread))
  size = ccall(:pthread_get_stacksize_np, Csize_t, (Ptr{Cvoid},), thread)
  top - size <= frame() < top
end

"Stop with an error where JavaScriptCore can't be called from. Where it can, give it back what Julia has freed."
guard() = begin
  athome() || error("JavaScript can run only in the main task of a thread, not in a task that @async or @spawn made")
  release_dropped()
end

# --- strings ------------------------------------------------------------------------------

"A JSStringRef of `s`, which the caller releases"
jsstring(s::AbstractString) = begin
  units = transcode(UInt16, String(s))
  ccall((:JSStringCreateWithCharacters, LIB), Handle, (Ptr{UInt16}, Csize_t), units, length(units))
end

release(s::Handle) = ccall((:JSStringRelease, LIB), Cvoid, (Handle,), s)

"Call `f` with a JSStringRef of `s`"
with(f, s::AbstractString) = begin
  ref = jsstring(s)
  try f(ref) finally release(ref) end
end

"The text of a JSStringRef"
text(s::Handle) = begin
  n = ccall((:JSStringGetLength, LIB), Csize_t, (Handle,), s)
  n == 0 && return ""
  transcode(String, unsafe_wrap(Array, ccall((:JSStringGetCharactersPtr, LIB), Ptr{UInt16}, (Handle,), s), n))
end

"The text that a script's value is as a string, as `String(value)` in a script gives"
text(c::Context, v::Handle) = begin
  s = ccall((:JSValueToStringCopy, LIB), Handle, (Handle, Handle, Ptr{Handle}), c.ref, v, C_NULL)
  s == C_NULL && return ""
  try text(s) finally release(s) end
end

# --- values -------------------------------------------------------------------------------

"Throw what a script threw, if `exception` holds anything"
check(c::Context, exception::Ref{Handle}) = begin
  v = exception[]
  v == C_NULL && return
  protect(c, v)
  throw(try failure(c, v) finally unprotect(c, v) end)
end

failure(c::Context, v::Handle) = begin
  isobject(c, v) || return ScriptError(text(c, v), "", 0, "")
  field(name) = (x = property(c, v, name); x == C_NULL || isnothing(julia(c, x)) ? "" : text(c, x))
  line = tryparse(Int, field("line"))
  ScriptError(text(c, v), field("sourceURL"), something(line, 0), field("stack"))
end

kind(c::Context, v::Handle) = ccall((:JSValueGetType, LIB), Cint, (Handle, Handle), c.ref, v)
isobject(c::Context, v::Handle) = kind(c, v) == 5

"The property `name` of a script's object, as a JSValueRef, or C_NULL when reading it throws"
property(c::Context, object::Handle, name::AbstractString) =
  with(s -> ccall((:JSObjectGetProperty, LIB), Handle, (Handle, Handle, Handle, Ptr{Handle}), c.ref, object, s, C_NULL), name)

"The Julia value of a script's value"
julia(c::Context, v::Handle) = begin
  k = kind(c, v)
  k <= 1 ? nothing :
  k == 2 ? ccall((:JSValueToBoolean, LIB), Bool, (Handle, Handle), c.ref, v) :
  k == 3 ? ccall((:JSValueToNumber, LIB), Cdouble, (Handle, Handle, Ptr{Handle}), c.ref, v, C_NULL) :
  k == 4 ? text(c, v) :
  k == 5 && ccall((:JSValueIsArray, LIB), Bool, (Handle, Handle), c.ref, v) ? items(c, v) :
  Object(c, v)
end

items(c::Context, array::Handle) = begin
  n = Int(ccall((:JSValueToNumber, LIB), Cdouble, (Handle, Handle, Ptr{Handle}), c.ref, property(c, array, "length"), C_NULL))
  Any[julia(c, ccall((:JSObjectGetPropertyAtIndex, LIB), Handle, (Handle, Handle, Cuint, Ptr{Handle}), c.ref, array, i, C_NULL)) for i in 0:n-1]
end

"The script's value of a Julia value, as a JSValueRef"
value(c::Context, ::Nothing) = ccall((:JSValueMakeNull, LIB), Handle, (Handle,), c.ref)
value(c::Context, ::Missing) = ccall((:JSValueMakeUndefined, LIB), Handle, (Handle,), c.ref)
value(c::Context, x::Bool) = ccall((:JSValueMakeBoolean, LIB), Handle, (Handle, Bool), c.ref, x)
value(c::Context, x::Real) = ccall((:JSValueMakeNumber, LIB), Handle, (Handle, Cdouble), c.ref, Float64(x))
value(c::Context, x::Union{AbstractString,Symbol,AbstractChar}) = with(s -> ccall((:JSValueMakeString, LIB), Handle, (Handle, Handle), c.ref, s), string(x))
value(c::Context, o::Object) = o.ref
value(c::Context, xs::Union{AbstractVector,Tuple}) = begin
  array = ccall((:JSObjectMakeArray, LIB), Handle, (Handle, Csize_t, Ptr{Handle}, Ptr{Handle}), c.ref, 0, C_NULL, C_NULL)
  for (i, x) in enumerate(xs)
    ccall((:JSObjectSetPropertyAtIndex, LIB), Cvoid, (Handle, Handle, Cuint, Handle, Ptr{Handle}), c.ref, array, i - 1, value(c, x), C_NULL)
  end
  array
end
value(c::Context, d::Union{AbstractDict,NamedTuple}) = begin
  object = ccall((:JSObjectMake, LIB), Handle, (Handle, Handle, Ptr{Cvoid}), c.ref, C_NULL, C_NULL)
  for (name, x) in pairs(d)
    set!(c, object, string(name), value(c, x))
  end
  object
end
value(c::Context, f::Function) = begin
  made = with(s -> ccall((:JSObjectMakeFunctionWithCallback, LIB), Handle, (Handle, Handle, Ptr{Cvoid}), c.ref, s, CALLED[]), "")
  # The function is kept for as long as the context is, since its Julia function is found by where it is
  protect(c, made)
  c.natives[made] = f
  made
end

set!(c::Context, object::Handle, name::AbstractString, v::Handle) = begin
  exception = Ref{Handle}(C_NULL)
  with(s -> ccall((:JSObjectSetProperty, LIB), Cvoid, (Handle, Handle, Handle, Handle, Cuint, Ptr{Handle}), c.ref, object, s, v, 0, exception), name)
  check(c, exception)
end

# --- a script calls Julia -----------------------------------------------------------------

# What JavaScriptCore calls when a script calls a function that `value(c, f)` made. Nothing that Julia throws may
# pass through JavaScriptCore, so it's thrown in the script.
called(ctx::Handle, fn::Handle, this::Handle, argc::Csize_t, argv::Ptr{Handle}, exception::Ptr{Handle})::Handle = begin
  c = nothing
  try
    c = CONTEXTS[ccall((:JSContextGetGlobalContext, LIB), Handle, (Handle,), ctx)].value::Context
    f = c.natives[fn]
    value(c, f((julia(c, unsafe_load(argv, i)) for i in 1:argc)...))
  catch e
    c === nothing && return C_NULL
    message = Ref(value(c, e isa ScriptError ? e.message : sprint(showerror, e)))
    unsafe_store!(exception, ccall((:JSObjectMakeError, LIB), Handle, (Handle, Csize_t, Ptr{Handle}, Ptr{Handle}), c.ref, 1, message, C_NULL))
    ccall((:JSValueMakeUndefined, LIB), Handle, (Handle,), c.ref)
  end
end

# --- Julia runs a script ------------------------------------------------------------------

"""
Run the script `code` in `c`, and give the value of its last statement. `name`
is what the script is called in an error, and `line` is the line of its file
that it starts on.
"""
evaluate(c::Context, code::AbstractString; name="", line=1) = begin
  isopen(c) || error("the context is closed")
  guard()
  exception = Ref{Handle}(C_NULL)
  v = with(code) do script
    with(name) do file
      ccall((:JSEvaluateScript, LIB), Handle, (Handle, Handle, Handle, Handle, Cint, Ptr{Handle}), c.ref, script, C_NULL, isempty(name) ? C_NULL : file, line, exception)
    end
  end
  check(c, exception)
  julia(c, v)
end

globals(c::Context) = ccall((:JSContextGetGlobalObject, LIB), Handle, (Handle,), c.ref)

Base.getindex(c::Context, name::AbstractString) = (guard(); julia(c, property(c, globals(c), name)))
Base.setindex!(c::Context, x, name::AbstractString) = (guard(); set!(c, globals(c), name, value(c, x)); x)

Base.getindex(o::Object, name::AbstractString) = (guard(); julia(o.context, property(o.context, o.ref, name)))
Base.setindex!(o::Object, x, name::AbstractString) = (guard(); set!(o.context, o.ref, name, value(o.context, x)); x)

"Call a script's function with Julia values"
(o::Object)(args...) = begin
  c = o.context
  isopen(c) || error("the context is closed")
  guard()
  refs = Handle[]
  exception = Ref{Handle}(C_NULL)
  v = try
    for x in args
      push!(refs, value(c, x))
      protect(c, refs[end])
    end
    ccall((:JSObjectCallAsFunction, LIB), Handle, (Handle, Handle, Handle, Csize_t, Ptr{Handle}, Ptr{Handle}), c.ref, o.ref, C_NULL, length(refs), refs, exception)
  finally
    foreach(r -> unprotect(c, r), refs)
  end
  check(c, exception)
  julia(c, v)
end

"Call the global function `name` of `c` with Julia values"
call(c::Context, name::AbstractString, args...) = begin
  f = c[name]
  f isa Object || error("the script has no function `$name`")
  f(args...)
end

"Ask JavaScriptCore to free what no script can reach"
collect!(c::Context) = ccall((:JSGarbageCollect, LIB), Cvoid, (Handle,), c.ref)

# A pointer to a Julia function is made when the program starts: one that's made while this file is compiled is no good later
__init__() = begin
  # To stop a script that runs too long, JavaScriptCore by default halts the thread from another thread and changes
  # the code that it's running. In a Julia program that never returns: the thread waits for ever. With this setting
  # the script itself looks, each time round a loop, whether it has to stop. It has to be set before the first context
  # is made. A loop of 300 million steps took 0.37 s with it and 0.31 s without.
  get!(ENV, "JSC_usePollingTraps", "1")
  CALLED[] = @cfunction(called, Handle, (Handle, Handle, Handle, Csize_t, Ptr{Handle}, Ptr{Handle}))
  STOP[] = @cfunction(stop, Bool, (Handle, Ptr{Cvoid}))
end

export Context, Object, ScriptError, evaluate, call
