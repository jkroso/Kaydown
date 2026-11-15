# A program that answers as Centient's server does, for centient_test.jl,
# takeoff_view_test.jl and project_page_test.jl. It answers each tool call
# with the name of the tool, whether it was asked about conduit, and the same
# two items, one contact, one supplier's catalogue and one quote whatever it's
# asked. A search of the catalogue "own" gives the business's own item and no
# more, and a search of the catalogue "acme" gives Acme's product and no more.
# The tool "fail" fails, "error" gives an error of the protocol, "quit" stops
# the program and "slow" never answers. A quote for the customer Nobody fails.
#
# The tool "make_job_from_page" answers as Centient does when it makes a job
# from a project page. The first time it's asked for a page, by the page's
# progress address, it makes the job with 10 tasks for 5 trades. The second
# time it has the job and adds 2 tasks, and after that it adds none. Its answer
# has what it was asked under "asked". A page whose progress address has
# "unreachable" in it fails.

const OWN = "{\"ref\":\"item 1\",\"name\":\"20mm conduit\",\"description\":\"Grey, 4 m lengths\",\"unit\":\"m\",\"price\":4.2,\"source\":\"Your items\"}"
const ACME = "{\"ref\":\"acme 77\",\"name\":\"Double power point\",\"unit\":\"each\",\"price\":12.5,\"source\":\"Acme Electrical\"}"
const REST = "\"contacts\":[{\"id\":5,\"name\":\"J Smith\"}],\"catalogues\":[{\"slug\":\"acme\",\"name\":\"Acme Electrical\",\"products\":1}]," *
             "\"number\":\"Q-0007\",\"id\":7,\"total\":123.45"
# How many times a job was asked for, by its page's progress address
const made = Dict{String,Int}()
"The answer to the request for a job in `line`"
job(line) = begin
  args = match(r"\"arguments\":(\{[^{}]*\})", line)[1]
  title = match(r"\"title\":\"([^\"]*)\"", args)
  progress = match(r"\"progress\":\"([^\"]*)\"", args)[1]
  n = made[progress] = get(made, progress, 0) + 1
  "{\"job\":12,\"title\":\"$(title === nothing ? "A job" : title[1])\",\"tasks\":5,\"steps\":$(n == 1 ? 10 : 12)," *
  "\"added\":$(n == 1 ? 10 : n == 2 ? 2 : 0),\"existed\":$(n > 1),\"asked\":$args}"
end
"The items that a line asks for: those of one catalogue, or all of them"
items(line) = occursin(r"\"catalogue\":\s*\"own\"", line) ? "[$OWN]" : occursin(r"\"catalogue\":\s*\"acme\"", line) ? "[$ACME]" : "[$OWN,$ACME]"

for line in eachline(stdin)
  id = match(r"\"id\":(\d+)", line)[1]
  tool = match(r"\"(search_catalogue|list_catalogues|find_contacts|lookup_items|create_quote|make_job_from_page|fail|error|quit|slow)\"", line)
  if occursin("server/discover", line)
    println("{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"resultType\":\"complete\",\"_meta\":{\"au.com.centient/company\":\"sample-co\"}}}")
  elseif tool[1] == "fail" || (tool[1] == "create_quote" && occursin("Nobody", line))
    println("{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"isError\":true,\"content\":[{\"type\":\"text\",\"text\":\"Centient has no contact called Nobody\"}]}}")
  elseif tool[1] == "make_job_from_page" && occursin("unreachable", line)
    println("{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"isError\":true,\"content\":[{\"type\":\"text\",\"text\":\"Couldn't reach the walkthrough service. Check the internet connection.\"}]}}")
  elseif tool[1] == "make_job_from_page"
    println("{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"isError\":false,\"structuredContent\":$(job(line))}}")
  elseif tool[1] == "error"
    println("{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32602,\"message\":\"Unknown tool: error\"}}")
  elseif tool[1] == "quit"
    println(stderr, "CENTIENT:{}\nThe books are locked")
    exit(1)
  elseif tool[1] != "slow"
    # A line that isn't an answer, then an answer that comes in two pieces
    println("not an answer")
    print("{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"isError\":false,")
    flush(stdout)
    sleep(0.05)
    println("\"structuredContent\":{\"tool\":\"$(tool[1])\",\"asked\":$(occursin("conduit", line)),\"items\":$(items(line)),$REST}}}")
  end
  flush(stdout)
end
