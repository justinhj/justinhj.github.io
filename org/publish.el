;; -*- flycheck-disabled-checkers: (emacs-lisp-checkdoc); byte-compile-warnings: (not free-vars) -*-
;; Run this then M-x org-publish

(setq project-root (locate-dominating-file "." "_config.yml"))

(setq org-publish-project-alist
  `(
    ("org-justinhj"
     ;; Path to your org files.
     :base-directory ,(concat project-root "org/posts")
     :base-extension "org"
     ;; Path to your Jekyll project.
     :publishing-directory ,(concat project-root "_posts")
     :recursive t
     :publishing-function org-html-publish-to-html
     :section-numbers nil
     :headline-levels 4
     :html-extension "html"
     :body-only t
     )
    ))
