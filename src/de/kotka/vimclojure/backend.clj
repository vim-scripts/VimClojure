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
     [de.kotka.vimclojure.util :as util]))

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
(defn complete-var-in-namespace
  "Complete the given symbol name in the given namespace."
  [the-name the-space]
  (let [publics (-> the-space symbol the-ns ns-map keys)
        publics (map name publics)]
    (reduce (fn [completions sym]
              (if (util/splitted-match the-name sym ["-"])
                (let [sym-var (ns-resolve (symbol the-space) (symbol sym))]
                  (conj completions [sym sym-var]))
                completions))
            [] publics)))

(defn complete-namespace
  "Complete the namespace from the given partial pattern."
  [the-name]
  (reduce (fn [completions nspace]
            (let [nspace-name (name (ns-name nspace))]
              (if (util/splitted-match the-name nspace-name ["\\." "-"])
                (conj completions [nspace-name nspace])
                completions)))
          [] (all-ns)))
