# A program that answers as Centient's server does, for centient_test.jl and
# takeoff_view_test.jl. It answers each tool call with the name of the tool,
# whether it was asked about conduit, and the same two items, one contact, one
# supplier's catalogue and one quote whatever it's asked. A search of the
# catalogue "own" gives the business's own item and no more, and a search of
# the catalogue "acme" gives Acme's product and no more. The tool "fail" fails,
# "error" gives an error of the protocol, "quit" stops the program and "slow"
# never answers. A quote for the customer Nobody fails.

const OWN = "{\"ref\":\"item 1\",\"name\":\"20mm conduit\",\"description\":\"Grey, 4 m lengths\",\"unit\":\"m\",\"price\":4.2,\"source\":\"Your items\"}"
const ACME = "{\"ref\":\"acme 77\",\"name\":\"Double power point\",\"unit\":\"each\",\"price\":12.5,\"source\":\"Acme Electrical\"}"
const REST = "\"contacts\":[{\"id\":5,\"name\":\"J Smith\"}],\"catalogues\":[{\"slug\":\"acme\",\"name\":\"Acme Electrical\",\"products\":1}]," *
             "\"number\":\"Q-0007\",\"id\":7,\"total\":123.45"
"The items that a line asks for: those of one catalogue, or all of them"
items(line) = occursin(r"\"catalogue\":\s*\"own\"", line) ? "[$OWN]" : occursin(r"\"catalogue\":\s*\"acme\"", line) ? "[$ACME]" : "[$OWN,$ACME]"

for line in eachline(stdin)
  id = match(r"\"id\":(\d+)", line)[1]
  tool = match(r"\"(search_catalogue|list_catalogues|find_contacts|lookup_items|create_quote|fail|error|quit|slow)\"", line)
  if occursin("server/discover", line)
    println("{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"resultType\":\"complete\",\"_meta\":{\"au.com.centient/company\":\"sample-co\"}}}")
  elseif tool[1] == "fail" || (tool[1] == "create_quote" && occursin("Nobody", line))
    println("{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"isError\":true,\"content\":[{\"type\":\"text\",\"text\":\"Centient has no contact called Nobody\"}]}}")
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
