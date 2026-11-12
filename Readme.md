# Kaydown

A Markdown editor for the Mac, made with [UI.jl](https://github.com/jkroso/UI.jl). It draws each line the way it will read, and you type in it. A code block in the language `ui` runs its Julia code and shows what the code makes. A code block in the language `sheet` works things out, like a small spreadsheet.

"Kaydown" is a working name, after Alan Kay.

## Run it

You need Julia and [Kip](https://github.com/jkroso/Kip.jl).

```sh
julia --project=. main.jl                # opens the welcome page
julia --project=. main.jl ~/notes        # opens a file or a folder
```

`pages/welcome.md` shows what the editor does. `pages/components.md` has a live block for each of UI.jl's components.

## Change it

Kaydown loads UI.jl by its GitHub path. To use your own copy of UI.jl, link it once:

```julia
using Kip
Kip.link("/path/to/UI.jl")
```

UI.jl has a script that runs an app and reloads each file when you save it:

```sh
julia --project=. ../UI.jl/examples/hot_reload.jl main.jl pages/components.md
```

## Build the app

```sh
julia --project=. app/build.jl             # writes build/Kaydown.app
julia --project=. app/build.jl --install   # and copies it into /Applications
```

The app runs without Julia installed. It is signed for your Mac only. `app/bundle.jl` lists what the build needs and the settings it takes.

## Make a release

1. Change the version in the `VERSION` file, and commit.
2. Run `julia --project=. release.jl`. It builds the app, signs it with a Developer ID certificate and has Apple notarise it. It writes `build/Kaydown-<version>.zip`.
3. Open the app from the zip file to check it.
4. Run `julia --project=. release.jl --publish`. It builds again, then tags the commit and puts the zip file on GitHub as a release.

The top of `release.jl` says how to store your Apple account for the notarising step. You do that once.
