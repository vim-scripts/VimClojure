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

(clojure.core/ns de.kotka.vimclojure.backend
  (:require
     [de.kotka.vimclojure.util :as util])
  (:import
     clojure.lang.RT
     (java.io File FileInputStream InputStreamReader
              LineNumberReader PushbackReader)))

; Documentation:
(defn doc-lookup
  "Lookup up the documentation for the given symbols in the given namespace.
  The documentation is returned as a string."
  [namespace symbols]
  (with-out-str
    (doseq [sym symbols]
      (cond
        (special-form-anchor sym)
        (print-special-doc sym "Special Form" (special-form-anchor sym))

        (syntax-symbol-anchor sym)
        (print-special-doc sym "Special Form" (syntax-symbol-anchor sym))

        :else
        (if-let [nspace (find-ns sym)]
          (print-namespace-doc nspace)
          (print-doc (ns-resolve namespace sym)))))))

(defn javadoc-path-for-class
  "Translate the name of a Class to the path of its javadoc file."
  [x]
  (-> x .getName (.replace \. \/) (.replace \$ \.) (.concat ".html")))

; Namespace Information:
(defn meta-info
  "Convert the meta data of the given Var into a map with the
  values converted to strings."
  [the-var]
  (reduce #(assoc %1 (first %2) (str (second %2))) {} (meta the-var)))

(defn symbol-info
  "Creates a tree node containing the meta information of the Var named
  by the fully qualified symbol."
  [the-symbol]
  (merge {:type "symbol" :name (name the-symbol)}
         (meta-info (find-var the-symbol))))

(defn var-info
  "Creates a tree node containing the meta information of the given Var."
  [the-var]
  (merge {:type "var" :name (str the-var)} (meta-info the-var)))

(defn ns-info
  "Creates a tree node containing the information about the given namespace."
  [the-namespace]
  {:name (-> the-namespace ns-name name) :type "namespace"
   :children (map #(-> % second var-info) (ns-interns the-namespace))})

; Omni Completion
(defmulti complete
  "Complete the given base according to the given prefix and completion-type
  in the context of the given namespace."
  {:arglists '([completion-type nspace prefix base])}
  (fn [completion-type _ _ _] completion-type))

(defmethod complete :full-var
  [_ the-space _ the-name]
  (let [publics (ns-map the-space)]
    (reduce (fn [completions sym]
              (if (util/splitted-match the-name (name sym) ["-"])
                (conj completions [sym (publics sym)])
                completions))
            [] (keys publics))))

(defmethod complete :local-var
  [_ the-context the-space the-name]
  (let [publics (if-let [the-real-space (get (ns-aliases the-context)
                                             the-space)]
                  (ns-publics the-real-space)
                  (-> the-space the-ns ns-publics))]
    (reduce (fn [completions sym]
              (if (util/splitted-match the-name (name sym) ["-"])
                (let [sym-var (publics sym)]
                  (conj completions [(str (name the-space) "/" (name sym))
                                     sym-var]))
                completions))
            [] (keys publics))))

(defmethod complete :alias
  [_ the-space _ the-name]
  (let [aliases (ns-aliases the-space)]
    (reduce (fn [completions aliass]
              (let [alias-name (name aliass)]
                (if (util/splitted-match the-name alias-name ["-"])
                  (conj completions [alias-name (aliases aliass)])
                  completions)))
            [] (keys aliases))))

(defmethod complete :import
  [_ the-space _ the-name]
  (let [imports (ns-imports the-space)]
    (reduce (fn [completions klass]
              (let [klass-name (name klass)]
                (if (util/splitted-match the-name klass-name ["-"])
                  (conj completions [klass-name (imports klass)])
                  completions)))
            [] (keys imports))))

(defmethod complete :namespace
  [_ _ _ the-name]
  (reduce (fn [completions nspace]
            (let [nspace-name (name (ns-name nspace))]
              (if (util/splitted-match the-name nspace-name ["\\." "-"])
                (conj completions [nspace-name nspace])
                completions)))
          [] (all-ns)))

(defmethod complete :static-field
  [_ the-space the-class the-name]
  (let [static? #(-> % .getModifiers java.lang.reflect.Modifier/isStatic)
        klass   (ns-resolve the-space the-class)]
    (loop [completions  {}
           fields       (seq (filter static? (concat (.getFields klass)
                                                     (.getMethods klass))))]
      (if fields
        (let [member      (first fields)
              member-name (.getName member)]
          (if (.startsWith member-name the-name)
            (recur (update-in completions [(str the-class "/" member-name)]
                              conj member)
                   (next fields))
            (recur completions (next fields))))
        (vec completions)))))

; Source lookup. Taken from clojure.contrib.repl-utils and modified to
; take a Var instead of a symbol.
(defn get-source
  "Returns a string of the source code for the given Var, if it can
  find it. This requires that the Var is defined in a namespace for
  which the .clj is in the classpath. Returns nil if it can't find
  the source."
  [the-var]
  (let [fname (:file (meta the-var))
        file  (File. fname)
        strm  (if (.isAbsolute file)
                (FileInputStream. file)
                (.getResourceAsStream (RT/baseLoader) fname))]
    (when strm
      (with-open [rdr (LineNumberReader. (InputStreamReader. strm))]
        (dotimes [_ (dec (:line ^the-var))] (.readLine rdr))
        (let [text (StringBuilder.)
              pbr (proxy [PushbackReader] [rdr]
                    (read [] (let [i (proxy-super read)]
                               (.append text (char i))
                               i)))]
          (read (PushbackReader. pbr))
          (str text))))))

; Source position
(defn source-position
  "Extract the position of the Var's source from its metadata."
  [the-var]
  (let [meta-info (meta the-var)
        file      (:file meta-info)
        line      (:line meta-info)]
    {:file file :line line}))
