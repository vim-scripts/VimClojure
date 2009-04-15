;-
; Copyright 2009 (c) Meikel Brandmeyer.
; All rights reserved.
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
; THE SOFTWARE.

(clojure.core/ns de.kotka.vimclojure.nails
  (:use
     [clojure.contrib.def :only (defvar)])
  (:require
     (de.kotka.vimclojure [repl :as repl]
                          [util :as util]
                          [backend :as backend]))
  (:import
     com.martiansoftware.nailgun.NGContext
     clojure.lang.LineNumberingPushbackReader
     (java.io BufferedReader InputStreamReader OutputStreamWriter PrintWriter)))

(defmacro defnail
  "Define a new Nail of the given name. A suitable class with the
  .nailMain method is generated. The arguments is a command line
  arguments specification vector suitable for with-command-line.
  The body will be installed as the body .nailMain method with the
  command-line arguments available according to the specification
  and the nailgun context as 'nailContext'."
  [nail usage arguments & body]
  `(do
     (gen-class
       :name    ~(symbol (str "de.kotka.vimclojure.nails." (name nail)))
       :prefix  ~(symbol (str (name nail) "-"))
       :methods [#^{:static true}
                 [~'nailMain [com.martiansoftware.nailgun.NGContext] ~'void]]
       :main    false)

     (defn ~(symbol (str (name nail) "-nailMain"))
       ~usage
       [~(with-meta 'nailContext {:tag 'NGContext})]
       (binding [~'*in*  (-> ~'nailContext
                           .in
                           InputStreamReader.
                           LineNumberingPushbackReader.)
                 ~'*out* (-> ~'nailContext .out OutputStreamWriter.)
                 ~'*err* (-> ~'nailContext .err PrintWriter.)]
         (util/with-command-line (.getArgs ~'nailContext)
           ~usage
           ~arguments
           ~@body)
         (.flush *out*)
         (.flush *err*)))))

(defnail DocLookup
  "Usage: ng de.kotka.vimclojure.nails.DocString [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace  (util/resolve-and-load-namespace nspace)
        symbols (map symbol (line-seq (BufferedReader. *in*)))]
    (print (backend/doc-lookup nspace symbols))
    (flush)))

(defnail FindDoc
  "Usage: ng de.kotka.vimclojure.nails.FindDoc"
  []
  (let [patterns (line-seq (BufferedReader. *in*))]
    (doseq [pattern patterns]
      (find-doc pattern))))

(defnail JavadocPath
  "Usage: ng de.kotka.vimclojure.nails.JavadocPath [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace         (util/resolve-and-load-namespace nspace)
        our-ns-resolve #(ns-resolve nspace %)]
    (doseq [path (map #(-> %
                         symbol
                         our-ns-resolve
                         backend/javadoc-path-for-class)
                      (util/stream->seq *in*))]
      (println path))))

(defnail SourceLookup
  "Usage: ng de.kotka.vimclojure.nails.SourceLookup [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace         (util/resolve-and-load-namespace nspace)
        our-ns-resolve #(ns-resolve nspace %)]
    (doseq [src (map #(-> %
                        symbol
                        our-ns-resolve
                        backend/get-source)
                     (util/stream->seq *in*))]
      (println src))))

(defnail MetaLookup
  "Usage: ng de.kotka.vimclojure.nails.MetaLookup [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace         (util/resolve-and-load-namespace nspace)
        our-ns-resolve #(ns-resolve nspace %)]
    (doseq [metainfo (map #(-> % symbol our-ns-resolve meta)
                     (util/stream->seq *in*))]
      (util/pretty-print metainfo))))

(defnail SourceLocation
  "Usage: ng de.kotka.vimclojure.nails.SourceLocation [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace         (util/resolve-and-load-namespace nspace)
        our-ns-resolve #(ns-resolve nspace %)]
    (doseq [positions (map #(-> %
                              symbol
                              our-ns-resolve
                              backend/source-position)
                           (util/stream->seq *in*))]
      (println (util/clj->vim positions)))))

(defnail DynamicHighlighting
  "Usage: ng de.kotka.vimclojure.nails.DynamicHighlighting"
  []
  (let [nspace    (read)
        c-c       (the-ns 'clojure.core)
        the-space (util/resolve-and-load-namespace nspace)
        refers    (remove #(= c-c (-> % second meta :ns)) (ns-refers the-space))
        aliases   (mapcat (fn [[the-alias the-alias-space]]
                            (map #(vector (symbol (name the-alias)
                                                  (name (first %)))
                                          (second %))
                                 (ns-publics the-alias-space)))
                          (ns-aliases the-space))
        namespaces (mapcat (fn [the-namespace]
                             (map #(vector (symbol
                                             (name (ns-name the-namespace))
                                             (name (first %)))
                                           (second %))
                                  (ns-publics the-namespace)))
                           (remove #(= c-c %) (all-ns)))
        vars      (set (concat refers aliases namespaces))
        macros    (set (filter #(-> % second meta :macro) vars))
        vars      (clojure.set/difference vars macros)
        fns       (set (filter #(let [v (util/safe-var-get (second %))]
                                  (or (fn? v)
                                      (instance? clojure.lang.MultiFn v)))
                               vars))
        vars      (clojure.set/difference vars fns)]
    (-> (hash-map "Func"     (map first fns)
                  "Macro"    (map first macros)
                  "Variable" (map first vars))
      util/clj->vim
      println)))

(defnail NamespaceOfFile
  "Usage: ng de.kotka.vimclojure.nails.NamespaceOfFile"
  []
  (let [of-interest '#{in-ns ns clojure.core/in-ns clojure.core/ns}
        in-seq      (util/stream->seq *in*)
        candidate   (first
                      (drop-while #(or (not (instance? clojure.lang.ISeq %))
                                       (not (contains? of-interest (first %))))
                                  in-seq))]
    (println
      (cond
        (not (instance? clojure.lang.ISeq candidate))    "user"
        ('#{ns clojure.core/ns} (first candidate))       (second candidate)
        ('#{in-ns clojure.core/in-ns} (first candidate)) (-> candidate
                                                           second
                                                           second)))))

(defnail NamespaceInfo
  "Usage: ng de.kotka.vimclojure.nails.NamespaceInfo"
  []
  (println (util/clj->vim (map #(-> % symbol find-ns backend/ns-info)
                               (line-seq (BufferedReader. *in*))))))

(defnail MacroExpand
  "Usage: ng de.kotka.vimclojure.nails.MacroExpand [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]
   [one?   o "Expand only the first macro."]]
  (let [nspace (util/resolve-and-load-namespace nspace)
        expand (if one
                 #(macroexpand-1 %)
                 #(macroexpand %))]
    (binding [*ns* nspace]
      (doseq [expr (util/stream->seq *in*)]
        (-> expr expand util/pretty-print-code)))))

(defnail Repl
  "Usage: ng de.kotka.vimclojure.nails.Repl [options]"
  [[start? s "Start a new Repl."]
   [stop?  S "Stop the Repl of the given id."]
   [run?   r "Run the input in the Repl context of the given id."]
   [id     i "The id of the repl to act on." "-1"]
   [nspace n "Change to namespace before executing the input." ""]
   [file   f "The filename to be set." "REPL"]
   [line   l "The initial line to be set." "0"]]
  (let [id     (Integer/parseInt id)
        line   (Integer/parseInt line)
        nspace (when (not= nspace "")
                 (util/resolve-and-load-namespace nspace))]
    (cond
      start (println (repl/start))
      stop  (repl/stop id)
      run   (repl/run id nspace file line))))

(defnail CheckSyntax
  "Usage: ng de.kotka.vimclojure.nails.CheckSyntax"
  []
  (try
    (dorun (util/stream->seq *in*))
    (println true)
    (catch Exception e
      (println false))))

(defnail Complete
  "Usage: ng de.kotka.vimclojure.nails.Complete"
  [[nspace n "Start completion in this namespace." "user"]
   [prefix p "Prefix used for the match, ie. the part before /." ""]
   [base   b "Base pattern to be matched."]]
  (let [nspace (util/resolve-and-load-namespace nspace)
        prefix (symbol prefix)]
    (if-not (and (= base "") (= prefix ""))
      (let [to-complete (util/decide-completion-in nspace prefix base)
            completions (mapcat #(backend/complete % nspace prefix base)
                                to-complete)
            completions (map #(apply util/make-completion-item %) completions)]
        (println (util/clj->vim completions)))
      (println "[]"))))
