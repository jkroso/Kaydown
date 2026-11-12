# Build Kaydown as a standalone Mac app with JuliaC:
#
#     julia --project=. app/build.jl
#
# It writes build/Kaydown.app, signed for this Mac only. Add `--install` to copy
# it into /Applications too. See bundle.jl for what the build needs and the
# settings it takes. To make a release that other Macs open, run release.jl.
#
# Leave APP_TRIM at no. A sheet and a live block run Julia code that the app
# has never seen, and a trimmed app can't compile new code.
#
# icon.jl draws the app's icon, icon.png.

include("bundle.jl")

"Kaydown's version, from the VERSION file"
const version = strip(read(joinpath(root, "VERSION"), String))

# macOS asks before the app can read your Desktop, Documents and Downloads
# folders, and shows this reason
reason = "Kaydown opens the Markdown files in it, and saves a file when you press ⌘S."
const app = build_app(name="Kaydown", program="kaydown", id="com.jkroso.kaydown", version=version,
          entry=joinpath(@__DIR__, "app.jl"), icon=joinpath(@__DIR__, "icon.png"), plist="""
            <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
            <key>NSDesktopFolderUsageDescription</key><string>$reason</string>
            <key>NSDocumentsFolderUsageDescription</key><string>$reason</string>
            <key>NSDownloadsFolderUsageDescription</key><string>$reason</string>
          """)
