___    ______           ______________     ________                    
__ |  / /__(_)______ _____  ____/__  /___________(_)___  _____________ 
__ | / /__  /__  __ `__ \  /    __  /_  __ \____  /_  / / /_  ___/  _ \
__ |/ / _  / _  / / / / / /___  _  / / /_/ /___  / / /_/ /_  /   /  __/
_____/  /_/  /_/ /_/ /_/\____/  /_/  \____/___  /  \__,_/ /_/    \___/ 
                                           /___/                       

This archive contains a syntax file, a filetype plugin and an indent plugin
for clojure.

The syntax is maintained by Toralf Wittner <toralf.wittner@gmail.com>. I
included it with his permission. All kudos for the highlighting go to Toralf.

Additionally I created a filetype and indent plugin. The blame for those go to
me. The indent pugin now also works with the vectors ([]) and maps ({}). The
ftplugin now comes with a completion dictionary. Since Clojure is still rather
evolving the completions might get outdated overtime. For this the generation
script by Parth Malwankar is included with his permission.

To setup the plugins copy the contents of this archive to your ~/.vim directory.
The ftdetect/clojure.vim sets up an autocommand to automatically detect .clj
files as clojure files. The rest works automagically when you enabled the
corresponding features (see :help :filetype).

-- Meikel Brandmeyer <mb@kotka.de>
   Frankfurt am Main, August 16th 2008
