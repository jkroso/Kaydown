# Ladder

Ladder is a novel OS design implemented as an app. By that I mean that Ladder fundamentally changes the way you think about what your computer is. With it, everything is an object. You don't build apps in Ladder. Instead, you change the behaviour of the objects. There are 3 types of fundamental objects, in this hierarchy: `Directory > File > Component`. Each contains instances of the one below it, and a directory can hold directories too. The specific types of objects available to you aren't important, though. What matters is that you have complete control over the way they behave.

For example, if you want a nice [email client](https://github.com/jkroso/Mail.lad) in Ladder, you just change the way your `~/mail` folder behaves. If you want a nice [Netflix-style media library](https://github.com/jkroso/Media.lad), you just change the way your `~/media` folder presents itself. You don't have a music player in Ladder. You have a music folder that behaves like one. You don't have a blog. You have a `~/blog` that knows how to put itself on the internet.

Why is this better? Well, so far it's not. I've just shown you examples of changing the way your data is presented to you, which is something you can already do using applications. If you want to change the way something looks, you change the application. With Ladder you change the `describe` function instead. Tomayto, tomahto. But the difference with Ladder is that you can also change the way objects behave towards each other, not just towards you. So when you create a to-do list, that to-do list doesn't just talk back to you. It will talk to the other objects on your computer, such as your calendar, your Gantt chart or your Kanban board. It might even talk to your alarm clock. And they can talk back. With Ladder, nothing is special because everything is. Even the settings page in ladder is just a file with some components in it. You could make your own.

The final thing that makes Ladder unique, and this is where it gets its name, is that it lets you explicitly choose what level of abstraction you want to work at. You set the slider anywhere between a snake and a ladder, and objects will present themselves at that level. This feature is more for the interface designers. It makes their life easier. But in turn that helps the user. Ladder itself demonstrates the value of this with its built-in Markdown editor. The task of designing a Markdown editor is trivial when you know your user is familiar with going up and down the ladder of abstraction.
 
## Get the app

1. Download `Ladder-<version>.zip` from the [newest release](https://github.com/jkroso/Ladder/releases/latest).
2. Open the zip file.
3. Move Ladder to your Applications folder, and open it.

The app needs a Mac with Apple silicon, and macOS 12 or later. To write down what's said in a recording, it needs macOS 26 or later. It opens on its welcome page, which shows what the editor does.

The app updates itself. A box on the settings page turns that off.
