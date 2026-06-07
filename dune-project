(lang dune 3.11)

(name ofzf)

(generate_opam_files true)

(package
 (name ofzf)
 (synopsis "A small fzf-like fuzzy finder written in OCaml")
 (description "ofzf is an educational, dependency-light fuzzy finder project inspired by fzf.")
 (license MIT)
 (homepage "https://github.com/shanenoi/ofzf")
 (source
  (uri git+https://github.com/shanenoi/ofzf.git))
 (depends ocaml dune))
