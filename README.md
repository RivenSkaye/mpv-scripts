# mpv-scripts #
Some self-serving scripts for mpv, mostly for me to get familiar with Lua

This repository is just a dumpsite for me for any mpv scripts I create. I decided it would be nice to get familiar with Lua just for the heck of it.
Then after pondering how to do this, I figured I might as well write some scripts for [mpv](https://mpv.io) since I use the player a lot and there's some functionality I can think of that I'd like to have.

## Scripts to be found here ##
If the script doesn't exist yet, expect a branch to be made soon™. If you have suggestions, feel free to fork or [contact me](#Contact) about it!
|    Name    |                Description                |
|------------|-------------------------------------------|
| yeetpls    | Delete playlist entries after playing them, or the entire playlist file when done |

# Installing #
For any and all of the scripts, they work as all mpv user scripts work. You put them in the global or user-local scripts directory. Information
on what folders these are on your system can be found in the [mpv docs](https://mpv.io/manual/master/#files). As always, Windows is a special case, located right below the normal OS info.

As for making sure it works, _just stick to the directory structure here_ and it should work just fine. If a script is multiple files, it should be a folder in the scripts directory that contains
a file named `main.ext` (where `ext` denotes the file type). If a script is just a single file, toss it into the scripts folder and it's done. **Never move a script file out of its folder,
or shit will hit the fan**. For example `main.lua` will be loaded, but it can't find any of its modules. Or a module will be loaded as standalone script, doing nothing _and_ causing `main.lua` to
throw errors. And that gives you those scary red messages on the CLI that make you panic and bug report.


# Contributing #
Branches in this repo will be ordered a bit different from most projects because I want to make contributing easy for all. And since this repo is supposed to be a collection, we don't want to accidentally push changes to an unstable file when another one has a stable update.

`master` is the classical branch for the stable versions of the script. Shouldn't change unless working updates are made. What's in here can be downloaded safely. Then there's the matter of adding new scripts or changing existing ones. This should be done by creating a branch named after the script. A few simple rules for both:
- Branch and Script names will be all lower case, with dashes or underscores to separate words;
- The choice between a dash or underscore is a free choice for whomever makes it; (both `yeet-pls` and `yeet_pls` are valid)
- Changes to a script should **only** be made in the branch of the same name;
- If a branch doesn't exist, create it;
- If a script is deemed stable and complete, the branch will be deleted after 9 weeks of inactivity;
- If you wish to contribute to this repo rather than fork, [shoot me a message](#Through-Discord) and we'll see if I can add you;
  - It's advisable to have sent in PRs before you request being added to the repo as a contributor.
  - In some cases of ~~favoritism~~ personal contacts, I'll add people I know and have faith in to write good code

# Contact #
## Through GitHub ##
Feel free to fork the repo and send in a PR, or use the Issue system to notify me of bugs and missing features.

## Through Discord ##
You can find me in various servers, or shoot me a DM. You should be able to find me pretty easily, my tag is `@Scuffed Riven#0042`.
