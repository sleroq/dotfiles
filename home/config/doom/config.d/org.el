(setq org-directory "~/Sync/Shared org")

(setq org-hide-emphasis-markers t)
(setq org-startup-indented t)

(setq writeroom-extra-line-spacing 4)

;; https://explog.in/notes/writingsetup.html#org51a5dfe
(customize-set-variable 'org-blank-before-new-entry
                        '((heading . nil)
                          (plain-list-item . nil)))
(setq org-cycle-separator-lines 1)

(add-hook 'org-mode-hook '+zen/toggle)
(add-hook 'org-agenda-mode-hook #'origami-mode)
(add-hook 'org-agenda-mode-hook #'org-super-agenda-mode)

;; (setq org-agenda-skip-deadline-prewarning-if-scheduled t)

(when (eq place-is-open t)
  (setq org-attach-id-dir (concat SAFE_PLACE "/files/attachments/"))
  (setq org-directory (concat SAFE_PLACE "/emacs-org/"))

  (setq org-todo-keywords
        '((sequence
           "TODO(t)"
           "DOING(w)"
           "LATER(l)"
           "HOLD(h)"
           "IDEA(i)"
           "|"
           "DONE(d!)"
           "KILL(k!)"
           "NO(n!)")
          (sequence "[ ](T)" "[-](S)" "|" "[X](D)")))
  (setq org-todo-keyword-faces
        '(("IDEA" . (:foreground "brightcyan"))
          ("REVIEW" . (:foreground "#FDFD96")))) ;; pastel-yellow
  (setq org-log-done 'time)

  (setq org-publish-project-alist
        (list
         (list
          "emacs-org"
          :recursive t
          :base-directory org-directory
          :publishing-directory (concat org-directory "public/")
          :exclude "public"
          :publishing-function 'org-html-publish-to-html
          :with-author nil
          :with-creator nil))))

;; Add some evil keybindings
(map!
 (:map org-super-agenda-header-map
       "j"     #'org-agenda-next-line
       "k"     #'org-agenda-previous-line
       "<tab>" #'origami-toggle-node))
