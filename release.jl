# Make a release of Kaydown: an app that other Macs open, in a zip file.
#
#     julia --project=. release.jl             builds build/Kaydown-<version>.zip
#     julia --project=. release.jl --publish   then puts it on GitHub as a release
#
# The version comes from the VERSION file. Change it before each release.
#
# It builds the app, signs it with your Developer ID certificate, and sends it
# to Apple to be notarised. Apple checks it for malware, which takes a few
# minutes. A Mac opens a notarised app without a warning.
#
# Before the first release, give `notarytool` your Apple account once. It keeps
# it in your keychain under the name "kaydown":
#
#     xcrun notarytool store-credentials kaydown --apple-id <your Apple ID> --team-id <your team ID>
#
# It asks for an app-specific password, which you make at account.apple.com
# under Sign-In and Security.
#
# These environment variables change what it uses:
#
#   APP_SIGN="Developer ID Application"   the certificate that signs the app
#   NOTARY_PROFILE=kaydown                the name notarytool keeps your account under
#   RELEASE_REPO=jkroso/Kaydown           the GitHub repo that gets the release

const publish = "--publish" in ARGS
const profile = get(ENV, "NOTARY_PROFILE", "kaydown")
const repo = get(ENV, "RELEASE_REPO", "jkroso/Kaydown")
haskey(ENV, "APP_SIGN") || (ENV["APP_SIGN"] = "Developer ID Application")

"Run `cmd` in Kaydown's folder and give back what it prints"
output(cmd) = readchomp(setenv(cmd, dir=@__DIR__))
ok(cmd) = success(pipeline(setenv(cmd, dir=@__DIR__), stdout=devnull, stderr=devnull))

const tag = "v" * strip(read(joinpath(@__DIR__, "VERSION"), String))

# Find what would stop the release before the build, which takes a few minutes
ok(`xcrun notarytool history --keychain-profile $profile`) ||
  error("notarytool has no account under the name \"$profile\". See the top of release.jl for how to store one.")
if publish
  isempty(output(`git status --porcelain`)) || error("Commit your changes first, so the release matches a commit.")
  isempty(output(`git tag --list $tag`)) || error("There is already a tag $tag. Change the VERSION file.")
  ok(`gh release view $tag --repo $repo`) && error("GitHub already has a release $tag. Change the VERSION file.")
end

include("app/build.jl")   # defines `app`, `out` and `version`

const zip = joinpath(out, "Kaydown-$version.zip")
pack() = (rm(zip, force=true); run(`ditto -c -k --keepParent $app $zip`))

pack()
println("Sending the app to Apple to be notarised. This takes a few minutes.")
const answer = read(`xcrun notarytool submit $zip --keychain-profile $profile --wait`, String)
println(answer)
if !occursin("status: Accepted", answer)
  id = match(r"id: ([0-9a-f-]+)", answer)
  id === nothing || run(ignorestatus(`xcrun notarytool log $(id[1]) --keychain-profile $profile`))
  error("Apple didn't notarise the app. Its reasons are above.")
end
# Put Apple's ticket in the app, so a Mac that's offline opens it too. Then zip the app again with the ticket in it.
run(`xcrun stapler staple $app`)
pack()
run(`spctl --assess --type execute --verbose $app`)
println("\n", zip, " is ready.")

if publish
  run(setenv(`git tag $tag`, dir=@__DIR__))
  run(setenv(`git push origin $tag`, dir=@__DIR__))
  run(`gh release create $tag $zip --repo $repo --title "Kaydown $version" --generate-notes`)
  println("Published ", tag, " on github.com/", repo)
else
  println("Run it again with --publish to put it on GitHub as release ", tag, ".")
end
