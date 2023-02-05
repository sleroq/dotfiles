;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Sleroq"
      user-mail-address "cantundo@pm.me")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples
(setq doom-font (font-spec :family "JetBrainsMono Nerd Font Mono" :size 16 :weight 'normal)
     doom-variable-pitch-font (font-spec :family "JetBrainsMono Nerd Font Mono" :size 17))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)
(setq undo-limit 50000000)

(setq server-socket-dir "/tmp/emacs1000")

(setq SAFE_PLACE (getenv "SAFE_PLACE"))

(setq place-is-open (and (string-empty-p SAFE_PLACE) (file-directory-p SAFE_PLACE)))

;;
;; Treemacs
;;

(map! :leader :desc "Treemacs toggle" :n "f t" #'+treemacs/toggle)
;; (map! :leader (:prefix ("f" . "file")) :desc "Treemacs toggle" :n "t" #'+treemacs/toggle)


;;
;; Org-mode
;;


(when (eq place-is-open t)
  (setq org-attach-id-dir (concat SAFE_PLACE "/files/attachments/"))
  (setq org-directory (concat SAFE_PLACE "/emacs-org/"))
  (after! org
    (setq org-image-actual-width 600)
    (setq org-todo-keywords
      '((sequence "TODO(t)" "HOLD(h)" "IDEA(i)" "|" "DONE(d!)" "KILL(k!)" "NO(n!)")
        (sequence "[ ](T)" "[-](S)" "|" "[X](D)")))
     (setq org-todo-keyword-faces
      '(("IDEA" . (:foreground "brightcyan"))
        ("REVIEW" . (:foreground "#FDFD96")))) ;; pastel-yellow
     (setq org-log-done 'time)))
     (setq org-publish-project-alist (list
       (list "emacs-org"
           :recursive t
           :base-directory org-directory
           :publishing-directory (concat org-directory "public/")
           :exclude "public"
           :publishing-function 'org-html-publish-to-html
           :with-author nil
           :with-creator nil)))

(setq org-startup-with-inline-images t)

(setq mixed-pitch-face 'variable-pitch)

(add-hook 'org-mode-hook 'writeroom-mode)
(add-hook 'org-mode-hook 'mixed-pitch-mode)

(setq org-html-head "<fink rel=\"stylesheet\" type=\"text/css\" href=\"https://gongzhitaao.org/orgcss/org.css\"/>")


;;
;; Org-Roam
;;

(when (eq place-is-open t)
  (setq org-roam-directory (concat SAFE_PLACE "/roam/"))

  (add-to-list 'org-publish-project-alist
      (list "roam"
            :recursive t
            :base-directory org-roam-directory
            :publishing-directory (concat SAFE_PLACE "/public/roam/")
            :publishing-function 'org-html-publish-to-html
            :with-author nil
            :section-numbers nil
            :with-creator nil))

  (setq org-roam-capture-templates
      `(("d" "default" plain "%?" :target
          (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+startup: show2levels
#+category: ${title}
#+title: ${title}\n")
          :unnarrowed t)

        ("p" "Person" plain
         (file ,(concat SAFE_PLACE "/templates/person.org"))
         :target
         (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: Birthday %^{Birthday|<0000-00-00>}
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Person%^G\n")
         :empty-lines-before 1
         :unnarrowed t)

        ("m" "Monthly archive" plain
         (file ,(concat SAFE_PLACE "/templates/monthly-archive.org"))
         :target
         (file+head "monthly/%<%Y-%m> ${slug}.org" "
#+PROPERTY: CREATED %T
#+category: %<%Y-%m> ${title}
#+title: %<%Y-%m> ${title}
#+startup: show2levels
#+filetags: :archive:\n")
         :empty-lines-before 1
         :unnarrowed t)

        ("a" "Anime" plain
         (file ,(concat SAFE_PLACE "/templates/anime.org"))
         :target
         (file+head "anime/%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Anime:\n")
         :empty-lines-before 1
         :unnarrowed t)

        ("g" "Gaming")

        ("gg" "Game" plain
         (file ,(concat SAFE_PLACE "/templates/game.org"))
         :target
         (file+head "gaming/%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Gaming:\n")
         :empty-lines-before 1
         :unnarrowed t)

        ("gn" "Game note" plain
         (file ,(concat SAFE_PLACE "/templates/game-note.org"))
         :target
         (file+head "gaming/%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Gaming%^G\n")
         :empty-lines-before 1
         :unnarrowed t)

        ("b" "Book" plain
         (file ,(concat SAFE_PLACE "/templates/book.org"))
         :target
         (file+head "reading/%<%Y%m%d%H%M%S>-${slug}.org" "
#+PROPERTY: CREATED %T
#+category: ${title}
#+title: ${title}
#+startup: show2levels
#+filetags: :Reading:\n")
         :empty-lines-before 1
         :unnarrowed t)

        ("o" "Answer" plain
         (file ,(concat SAFE_PLACE "/templates/answer.org"))
         :target
         (file+head "answers/%<%Y%m%d%H%M%S>-${slug}.org" "
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
            org-roam-ui-open-on-start t))

  ;; Org-roam search with Deft (https://www.orgroam.com/manual.html#Full_002dtext-search-with-Deft)
  (setq deft-use-filter-string-for-filename t)
  (setq deft-directory org-roam-directory)
  (setq deft-recursive t)
  (setq deft-strip-summary-regexp
    (concat "\\("
            "^:.+:.*\n" ; any line with a :SOMETHING:
            "\\|^#\\+.*\n" ; anyline starting with a #+
            "\\|^\\*.+.*\n" ; anyline where an asterisk starts the line
            "\\)"))

  (advice-add 'deft-parse-title :override
    (lambda (file contents)
      (if deft-use-filename-as-title
        (deft-base-filename file)
      (let* ((case-fold-search 't)
          (begin (string-match "title: " contents))
          (end-of-begin (match-end 0))
          (end (string-match "\n" contents begin)))
      (if begin
        (substring contents end-of-begin end)
        (format "%s" file)))))))


;;
;; Agenda
;;

(defun my/org-roam-filter-by-tag (tag-name)
  (lambda (node)
    (member tag-name (org-roam-node-tags node))))

(defun my/org-roam-list-notes-by-tag (tag-name)
  (mapcar #'org-roam-node-file
    (seq-filter
      (my/org-roam-filter-by-tag tag-name)
      (org-roam-node-list))))

(defun my/org-update-agenda-files ()
  (interactive)
  ;; Add to agenda only files with tag Board:
  (setq org-agenda-files (my/org-roam-list-notes-by-tag "Board"))
  (add-to-list 'org-agenda-files "~/Sync/Shared org/")
  (add-to-list 'org-agenda-files (concat SAFE_PLACE "/emacs-org/")))

;; Update agenda file-list for new session
(if (eq place-is-open t)
  (after! org-roam
    (my/org-update-agenda-files)))


;;
;; Gemini
;;

(after! org
  (use-package ox-gemini))

(map! :leader (:prefix ("l" "custom")) :desc "Open Elpher" :n "l e" #'elpher)

(if (eq place-is-open t)
  (add-to-list 'org-publish-project-alist
    (list "gemini"
       :recursive t
       :base-directory (concat SAFE_PLACE "/gemini/")
       :publishing-directory "~/develop/other/gemini/"
       :publishing-function 'org-gemini-publish-to-gemini
       :with-author nil
       :section-numbers nil
       :with-creator nil)))


;;
;; Spellcheck
;;

(with-eval-after-load "ispell"
  (add-to-list
   'ispell-local-dictionary-alist
   '("en_US-large,ru_RU" "[[:alpha:]]" "[^[:alpha:]]" "['0-9]" t
    ("-d" "en_US-large,ru_RU") nil
    utf-8))

  (setq ispell-dictionary "en_US-large,ru_RU")

  (if (eq place-is-open t)
      (setq ispell-personal-dictionary (concat SAFE_PLACE "/files/ispell-dictionary.txt"))))

;;
;; Vterm
;;

(setq vterm-shell "/usr/bin/zsh")

;;
;; Autosave
;;

(setq auto-save-visited-mode t)
(setq auto-save-default t)

(defun save-all ()
  (interactive)
  (save-some-buffers t))

(add-function :after after-focus-change-function 'save-all)

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
