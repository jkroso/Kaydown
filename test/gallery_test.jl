# Tests for gallery.jl. Run them with `julia -O0 --project=. test/gallery_test.jl`.
# The files that they list are made in a temporary folder. They hold a few
# letters, not pictures: gallery.jl goes by the names of the files.

@use Test: @test, @testset
@use "../gallery" => G

const KINDS = (".png", ".jpg")
const dir = mktempdir()
"Make a file in the page's folder, and say when it last changed: `age` seconds ago"
file(name, age=0) = begin
  path = joinpath(dir, name)
  mkpath(dirname(path))
  write(path, "x")
  age == 0 || run(`touch -t $(Libc.strftime("%Y%m%d%H%M.%S", time() - age)) $path`)
  path
end
names(found) = [p.name for p in found.pictures]
found_in(lines) = G.pictures(G.gallery(lines), dir, kinds=KINDS)

file("photos/photo 10.png", 300); file("photos/photo 2.png", 100); file("photos/Photo 1.JPG", 200)
file("photos/notes.txt"); file("photos/.hidden.png"); file("photos/deep/inside.png")
file("front.png", 50); file("plans/site.png", 400); file("plans/list.txt")

@testset "reading and writing" begin
  g = G.gallery(["in: photos/", "Sort: Newest", "size:large", "columns: 3", "", "plans/site.png", "  front.png "])
  @test g.folder == "photos" && g.sort == :newest && g.size == :large
  @test g.listed == ["plans/site.png", "front.png"] && g.other == ["columns: 3"]
  @test G.written(g) == ["in: photos", "sort: newest", "size: large", "columns: 3", "plans/site.png", "front.png"]
  # An empty block shows the page's own folder, by name, with medium squares. It stays empty.
  e = G.gallery(String[])
  @test e.folder === nothing && e.sort == :name && e.size == :medium && isempty(G.written(e))
  # A line that can't be read changes nothing
  w = G.gallery(["size: huge", "sort: sideways", "in: ."])
  @test w.size == :medium && w.sort == :name && w.folder == "" && G.written(w) == ["in: ."]
  @test G.gallery(["in:photos"]).folder == "photos"
  # The button goes round the three sizes
  @test G.next_size(:medium) == :large && G.next_size(:large) == :small && G.next_size(:small) == :medium
end

@testset "the pictures of a folder" begin
  found = found_in(["in: photos"])
  # In the order of their names as a person reads them. A hidden file, a file that isn't a picture and a folder are left out.
  @test names(found) == ["Photo 1.JPG", "photo 2.png", "photo 10.png"]
  @test found.folder == 3 && isempty(found.lost) && isempty(found.problem)
  @test found.pictures[1].path == joinpath(dir, "photos", "Photo 1.JPG")
  @test G.summary(G.gallery(["in: photos"]), found) == "3 pictures in photos"
  # The newest first
  @test names(found_in(["in: photos", "sort: newest"])) == ["photo 2.png", "Photo 1.JPG", "photo 10.png"]
  # An empty block shows the page's own folder
  own = found_in(String[])
  @test names(own) == ["front.png"] && G.summary(G.gallery(String[]), own) == "1 picture in this folder"
end

@testset "pictures that the block lists" begin
  lines = ["plans/site.png", "front.png", "plans/list.txt", "gone.png"]
  found = found_in(lines)
  # Only the ones that it lists, in the order of their lines
  @test names(found) == ["site.png", "front.png"] && found.folder == 0
  @test found.lost == ["plans/list.txt", "gone.png"]
  @test G.lost_words(found.lost) == "No picture at plans/list.txt or gone.png" && G.lost_words(String[]) == ""
  @test G.summary(G.gallery(lines), found) == "2 pictures"
  # With a folder, they come after the folder's pictures. One that's in the folder shows once.
  lines = ["in: photos", "plans/site.png", "photos/photo 2.png", joinpath(dir, "front.png")]
  found = found_in(lines)
  @test names(found) == ["Photo 1.JPG", "photo 2.png", "photo 10.png", "site.png", "front.png"]
  @test G.summary(G.gallery(lines), found) == "3 pictures in photos, and 2 more"
  @test names(found_in([lines; "sort: newest"])) == ["front.png", "photo 2.png", "Photo 1.JPG", "photo 10.png", "site.png"]
end

@testset "nothing to show" begin
  none = found_in(["in: plans/empty"])
  @test isempty(none.pictures) && none.problem == "There's no folder called “plans/empty” beside this page."
  mkpath(joinpath(dir, "bare"))
  bare = found_in(["in: bare"])
  @test bare.problem == "No pictures in bare" && G.summary(G.gallery(["in: bare"]), bare) == "No pictures in bare"
  @test found_in(["gone.png"]).problem == "No pictures"
  # A page with no folder yet
  @test isempty(G.pictures(G.gallery(String[]), "", kinds=KINDS).pictures)
end

@testset "the grid" begin
  # As many columns as fit, and the squares take all the room
  g = G.grid(12, 700, :medium)
  @test g.columns == 5 && g.rows == 3 && g.side ≈ (700 - 4G.GAP) / 5
  @test g.columns * g.side + (g.columns - 1) * G.GAP ≈ 700
  @test G.grid(12, 700, :small).columns == 8 && G.grid(12, 700, :large).columns == 3
  # A block that's narrower than one square has one column
  @test G.grid(3, 60, :large) == (columns=1, rows=3, side=60.0)
  @test G.grid(0, 700, :medium).rows == 0 && G.tall(0, 100) == 0
  @test G.tall(3, 100) == 300 + 2G.GAP
  # Only the rows that show
  @test G.rows_between(0, 250, 10, 100) == 1:3
  @test G.rows_between(540, 700, 10, 100) == 6:7
  @test isempty(G.rows_between(-500, -10, 10, 100)) && isempty(G.rows_between(5000, 6000, 10, 100))
  @test G.rows_between(-100, 99999, 10, 100) == 1:10
  @test G.row_places(2, 5, 12) == 6:10 && G.row_places(3, 5, 12) == 11:12
  # The small picture of a file has the pixels that its square needs
  @test G.pixels(80) == 256 && G.pixels(100) == 400 && G.pixels(133) == 400 && G.pixels(228) == 640 && G.pixels(600) == 1024
  # A square shows the middle of a picture
  @test G.crop(300, 100) == (100.0, 0.0, 100, 100) && G.crop(100, 300) == (0.0, 100.0, 100, 100) && G.crop(50, 50) == (0.0, 0.0, 50, 50)
end

@testset "a file that's dropped is copied into the folder" begin
  from = file("drop/new.png")
  to = G.keep(joinpath(dir, "photos"), from)
  @test to == joinpath(dir, "photos", "new.png") && isfile(to) && isfile(from)
  # Another file of that name gets a number
  @test G.keep(joinpath(dir, "photos"), from) == joinpath(dir, "photos", "new-2.png")
  # A file that's in the folder already stays where it is
  @test G.keep(joinpath(dir, "photos"), to) == to && !isfile(joinpath(dir, "photos", "new-3.png"))
  # A folder that isn't there is made
  @test G.keep(joinpath(dir, "later", "site"), from) == joinpath(dir, "later", "site", "new.png")
  @test G.keep(joinpath(dir, "photos"), joinpath(dir, "no such file.png")) === nothing
end
