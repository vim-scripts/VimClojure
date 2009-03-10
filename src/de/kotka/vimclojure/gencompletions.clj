; Copyright (c) 2008 Parth Malwankar
; Copyright (c) 2008 Meikel Brandmeyer
; All rights reserved.
;
; A small script to generate a dictionary of Clojure's core
; functions. The script was written by Parth Malwankar. It
; is included in VimClojure with his permission.
;  -- Meikel Brandmeyer, 16 August 2008
;     Frankfurt am Main, Germany
;
; Move to new main functionality.
;  -- Meikel Brandmeyer, 23 November 2008
;
; See also: http://en.wikibooks.org/wiki/Clojure_Programming

(ns de.kotka.vimclojure.gencompletions
  (:gen-class
     :main true))

(defmacro with-out-file [pathname & body]
  `(with-open [stream# (new java.io.FileWriter ~pathname)]
     (binding [*out* stream#]
       ~@body)))

(defn -main
  [nspace]
  (let [completions (keys (ns-publics (symbol nspace)))]
    (with-out-file (str nspace "-keys.txt")
      (doseq [x (sort completions)]
        (println x)))))
