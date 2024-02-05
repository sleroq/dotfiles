(when (eq place-is-open t)
  (setq org-roam-directory (concat SAFE_PLACE "/roam/"))

  (add-to-list
   'org-publish-project-alist
   (list
    "roam"
    :recursive t
    :base-directory org-roam-directory
    :publishing-directory (concat SAFE_PLACE "/public/roam/")
    :publishing-function 'org-html-publish-to-html
    :with-author nil
    :section-numbers nil
    :with-creator nil))

  (setq org-roam-capture-templates
        `(("d"
           "default"
           plain
           "%?"
           :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+startup: show2levels
#+category: ${title}
#+title: ${title}\n")
           :unnarrowed t)

          ("p"
           "Person"
           plain
           (file ,(concat SAFE_PLACE "/templates/person.org"))
           :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: Birthday %^{Birthday|<0000-00-00>}
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Person%^G\n")
           :empty-lines-before 1
           :unnarrowed t)

          ("m" "Monthly archive" plain
           (file
            ,(concat SAFE_PLACE "/templates/monthly-archive.org"))
           :target (file+head "monthly/%<%Y-%m> ${slug}.org" "
#+PROPERTY: CREATED %T
#+category: %<%Y-%m> ${title}
#+title: %<%Y-%m> ${title}
#+startup: show2levels
#+filetags: :archive:\n")
           :empty-lines-before 1
           :unnarrowed t)

          ("w" "Weekly archive" plain
           (file
            ,(concat SAFE_PLACE "/templates/weekly-archive.org"))
           :target (file+head "weekly/%<%Y-%m-%d> ${slug}.org" "
#+PROPERTY: CREATED %T
#+category: %<%Y-%m-%d> ${title}
#+title: %<%Y-%m-%d> ${title}
#+startup: show2levels
#+filetags: :archive:\n")
           :empty-lines-before 1
           :unnarrowed t)

          ("a"
           "Anime"
           plain
           (file ,(concat SAFE_PLACE "/templates/anime.org"))
           :target (file+head "anime/%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Anime:\n")
           :empty-lines-before 1
           :unnarrowed t)

          ("g" "Gaming")

          ("gg"
           "Game"
           plain
           (file ,(concat SAFE_PLACE "/templates/game.org"))
           :target (file+head "gaming/%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Gaming:\n")
           :empty-lines-before 1
           :unnarrowed t)

          ("gn"
           "Game note"
           plain
           (file ,(concat SAFE_PLACE "/templates/game-note.org"))
           :target (file+head "gaming/%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Gaming%^G\n")
           :empty-lines-before 1
           :unnarrowed t)

          ("b"
           "Book"
           plain
           (file ,(concat SAFE_PLACE "/templates/book.org"))
           :target (file+head "reading/%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Reading:\n")
           :empty-lines-before 1
           :unnarrowed t)

          ("o"
           "Answer"
           plain
           (file ,(concat SAFE_PLACE "/templates/answer.org"))
           :target (file+head "answers/%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Answer:\n")
           :empty-lines-before 1
           :unnarrowed t)))

  (use-package! websocket
      :after org-roam)


  (use-package! org-roam-ui
      :after org;; or :after org-roam
  ;;  if you don't care about startup time, use
  ;;  :hook (after-init . org-roam-ui-mode)
      :config
      (setq org-roam-ui-sync-theme t
            org-roam-ui-follow t
            org-roam-ui-update-on-save t
            org-roam-ui-open-on-start t)))

;;`Agenda'

(defun my/org-roam-filter-by-tag (tag-name)
  (lambda (node)
    (member tag-name (org-roam-node-tags node))))

(defun my/org-roam-list-notes-by-tag (tag-name)
  "Return a list of note files containing 'project' tag." ;
  (seq-uniq
   (seq-map
    #'car
    (org-roam-db-query
     [:select [nodes:file]
      :from tags
      :left-join nodes
      :on (= tags:node-id nodes:id)
      :where (= tag $s1)]
     tag-name))))

(defun my/org-update-agenda-files ()
  (interactive)
  ;; Add to agenda only files with tag Board
  (setq org-agenda-files (my/org-roam-list-notes-by-tag "Board"))
  (add-to-list 'org-agenda-files "~/Sync/Shared org/")
  (add-to-list 'org-agenda-files (concat SAFE_PLACE "/emacs-org/")))

;; Update agenda file-list for new session
(if (eq place-is-open t)
    (after! org-roam
      (my/org-update-agenda-files)

      (setq org-super-agenda-groups
            '((:name "Doing"
               :todo ("DOING"))
               (:name "Todo"
               :todo ("TODO"))
               (:name "Hold"
               :todo ("Hold"))
               (:name "Later"
               :todo ("LATER"))
               (:name "Idea"
               :todo ("IDEA"))
               (:name "Done"
               :todo ("DONE"))
               (:name "Canceled"
               :todo ("KILL" "NO"))
               (:auto-todo)))

      (setq org-agenda-prefix-format
            '((agenda  . "  • ")
              (timeline  . "  % s")
              (todo  . "  • ")
              (tags  . "  • ")
              (search . " %i %-12:c")))

      (setq org-agenda-todo-keyword-format "")

      (setq org-agenda-custom-commands
            '(("r" "Reading" todo ""
               ((org-agenda-files (my/org-roam-list-notes-by-tag "Reading"))
                (org-super-agenda-groups
                 '((:name "Reading"
                    :todo ("READING"))
                   (:name "Read"
                    :todo ("READ"))
                   (:name "Idea"
                    :todo ("IDEA"))
                   (:name "Finished"
                    :todo ("FINISHED"))
                   (:auto-todo)))))
              ("a" "Anime" todo ""
               ((org-agenda-files (my/org-roam-list-notes-by-tag "Anime"))
                (org-super-agenda-groups
                   '((:name "Watching"
                      :todo ("WATCHING"))
                     (:name "Watch"
                      :todo ("WATCH"))
                     (:name "Idea"
                      :todo ("IDEA")) (:auto-todo)))))
              ("t" "Technical" todo ""
               ((org-agenda-files (my/org-roam-list-notes-by-tag "Technical"))))
              ("j" "General" tags-todo "category=\"General Journal\"")
              ("g" . "Gaming")
              ("gg" "Board" tags-todo "category=\"Gaming Board\""
                 ((org-super-agenda-groups
                   '((:name "Playing"
                      :todo ("PLAYING"))
                     (:name "Stopped"
                      :todo ("HOLD"))
                     (:name "Play"
                      :todo ("PLAY"))
                     (:name "Idea"
                      :todo ("IDEA"))
                     (:auto-todo)))))
              ("gj" "Journal" tags-todo "category<>\"Gaming Board\""
               ((org-agenda-files (my/org-roam-list-notes-by-tag "Gaming"))
                (org-agenda-todo-keyword-format "%-1s")
                (org-super-agenda-groups
                   '((:name "Journal" :tag "Board")
                     (:auto-category)))))))))

;;`Journal'
(if (eq place-is-open t)
    (setq org-roam-dailies-directory "journals/")

    ;; Weekly journal
    (setq org-roam-dailies-capture-templates
    '(("d" "default" entry
    #'org-roam-capture--get-point
    "* %?"
    :file-name "%<%Y-%m>"
    :head "#+TITLE: %<%Y-%m>\n\n\n"
    :olp ("%<%Y-%m-%d>")))))

; (if (eq place-is-open t)
;     (setq org-journal-dir (concat org-roam-directory "/journals/")
;           org-journal-file-type 'weekly
;           org-journal-enable-agenda-integration t
;           org-journal-enable-agenda-integration t))

; (defun my-old-carryover (old_carryover)
;   (save-excursion
;     (let ((matcher (cdr (org-make-tags-matcher org-journal-carryover-items))))
;       (dolist (entry (reverse old_carryover))
;         (save-restriction
;           (narrow-to-region (car entry) (cadr entry))
;           (goto-char (point-min))
;           (org-scan-tags '(lambda ()
;                             (org-set-tags ":carried:"))
;                          matcher org--matcher-tags-todo-only))))))
;
; (setq org-journal-handle-old-carryover 'my-old-carryover)
;
; (defun org-journal-file-header-func (time)
;   "Custom function to create journal header."
;   (concat
;     (pcase org-journal-file-type
;       (`daily "#+TITLE: Daily Journal\n#+STARTUP: showeverything#+filetags: :journal:")
;       (`weekly "#+TITLE: Weekly Journal\n#+STARTUP: folded\n#+filetags: :journal:")
;       (`monthly "#+TITLE: Monthly Journal\n#+STARTUP: folded#+filetags: :journal:")
;       (`yearly "#+TITLE: Yearly Journal\n#+STARTUP: folded#+filetags: :journal:"))))
;
; (setq org-journal-file-header 'org-journal-file-header-func)
;
; (defun org-journal-find-location ()
;   ;; Open today's journal, but specify a non-nil prefix argument in order to
;   ;; inhibit inserting the heading; org-capture will insert the heading.
;   (org-journal-new-entry t)
;   (unless (eq org-journal-file-type 'daily)
;     (org-narrow-to-subtree))
;   (goto-char (point-max)))
;
; (setq org-capture-templates '(("j" "Journal entry" plain (function org-journal-find-location)
;                                "** %(format-time-string org-journal-time-format)%^{Title}\n%i%?"
;                                :jump-to-captured t :immediate-finish t)))

;; TODO: Add capture temlate for org-mode
