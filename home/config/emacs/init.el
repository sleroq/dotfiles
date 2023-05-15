(setq
 user-full-name "Sleroq"
 user-mail-address "hireme@sleroq.link")

;; Emacs window size and position
(setq default-frame-alist '((width . 120) (height . 40)))
(setq initial-frame-alist '((top . 0) (left . 300)))

(setq
 undo-limit 50000000
 evil-want-fine-undo t
 auto-save-default t)

;; Save history
(savehist-mode 1)
(add-to-list 'savehist-additional-variables 'kill-ring) ;; for example

;; Define the init file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; Font
(set-face-attribute 'default nil
                    :font "JetBrainsMono Nerd Font"
                    :height 140)

;; Encrypted directory with my notes, dictionary and other stuff
(setq SAFE_PLACE (getenv "SAFE_PLACE"))
(setq place-is-open
      (and (not (string-empty-p SAFE_PLACE))
           (file-directory-p SAFE_PLACE)))

(defalias 'yes-or-no-p 'y-or-n-p)

;;
;; Packages:
;;
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el"
                         user-emacs-directory))
      (bootstrap-version 6))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent
         'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))
(setq package-enable-at-startup nil)

(straight-use-package 'use-package)
(straight-use-package 'org)

;; Coding
(straight-use-package 'elisp-autofmt)
(straight-use-package 'typescript-mode)

;; General must-have packages
(straight-use-package 'neotree)
(straight-use-package 'all-the-icons)
(setq neo-theme 'icons)

(straight-use-package 'magit)
;; format: off
(use-package blamer
             :straight (:host github :repo "artawower/blamer.el")
             :custom
             (blamer-idle-time 0.3)
             (blamer-min-offset 70)
             :custom-face
             (blamer-face ((t :foreground "#7a88cf"
                              :background nil
                              :height 140
                              :italic t))))
;; format: on
(add-hook 'prog-mode-hook 'blamer-mode)

(use-package diff-hl
             :straight (:host github :repo "dgutov/diff-hl"))
(global-diff-hl-mode)

(straight-use-package 'ivy)

(straight-use-package 'helm)
(straight-use-package 'helm-projectile)
(helm-projectile-on)

(straight-use-package 'projectile)
(projectile-mode +1)
(setq projectile-complete-system 'ivy)

(straight-use-package 'sis)
(sis-ism-lazyman-config "1" "2" 'fcitx5)

(sis-global-cursor-color-mode t)
;; enable the /respect/ mode
(sis-global-respect-mode t)
;; enable the /context/ mode for all buffers
(sis-global-context-mode t)
;; enable the /inline english/ mode for all buffers
(sis-global-inline-mode t)

(straight-use-package 'highlight-thing)
(add-hook 'prog-mode-hook 'highlight-thing-mode)
;; Change hi-yellow face to make it more readable
(custom-set-faces
   '(highlight-thing ((t (:background "#8a846a" :foreground "black")))))
(setq highlight-thing-limit-to-region-in-large-buffers-p nil
    highlight-thing-narrow-region-lines 15
    highlight-thing-large-buffer-limit 5000)

;; Evil-mode 
(setq evil-want-keybinding nil)
(straight-use-package 'evil)
(straight-use-package 'evil-collection)
(evil-collection-init)
(evil-set-undo-system 'undo-redo)
(evil-mode 1)

;; Completion
(straight-use-package 'company)
(company-mode 1)

(with-eval-after-load 'company
  ;; disable inline previews
  (delq 'company-preview-if-just-one-frontend company-frontends))

;; format: off
(use-package copilot
             :straight (:host github :repo "zerolfx/copilot.el" :files ("dist" "*.el"))
             :ensure t
             :hook (prog-mode . copilot-mode)
             :bind (("C-c M-f" . copilot-complete)
                    :map copilot-completion-map
                    ("C-g" . 'copilot-clear-overlay)
                    ("M-p" . 'copilot-previous-completion)
                    ("M-n" . 'copilot-next-completion)
                    ("<tab>" . 'copilot-accept-completion)))
;; format: on
(add-hook 'text-mode-hook 'copilot-mode )

;;
;; Look and feel
;;

;; Case-insensitive and partial completion in searches
(straight-use-package 'orderless)
(setq
 completion-styles '(orderless basic)
 completion-category-overrides '((file (styles basic partial-completion))))

; Keyboard-centric user interface
(setq inhibit-startup-message t)
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode t)

; Theme
(straight-use-package
 '(zeno-theme :type git :host github :repo "zenobht/zeno-theme"))
(load-theme 'zeno t)

; Ido - switching between buffers
(require 'ido)
(ido-mode t)
(setq
 ido-everywhere t
 ido-enable-prefix nil
 ido-enable-flex-matching t
 ido-auto-merge-work-directories-length nil
 ;;ido-use-filename-at-point t
 ido-max-prospects 10
 ido-create-new-buffer 'always
 ;; ido-use-virtual-buffers   t
 ;; ido-handle-duplicate-virtual-buffers 2
 ido-default-buffer-method 'selected-window
 ido-default-file-method 'selected-window)

(add-hook
 'ido-make-file-list-hook
 (lambda ()
   (define-key
    ido-file-dir-completion-map (kbd "SPC") 'self-insert-command)))

(setq ido-decorations (quote ("\n-> " "" "\n " "\n ..." "[" "]" "
  [No match]"
              " [Matched]" " [Not readable]" " [Too big]" "
  [Confirm]")))
(defun ido-disable-line-truncation ()
  (set (make-local-variable 'truncate-lines) nil))
(add-hook 'ido-minibuffer-setup-hook 'ido-disable-line-truncation)

;; Using ido for M-x
(use-package smex
  :straight (:host github :repo "nonsequitur/smex" :branch "master" :files ("*.el" "out"))
  :bind (("M-x" . smex)
         ("M-X" . smex-major-mode-commands))
  :config (smex-initialize))

;; 
;; Org-mode
;;

;; Enable templates
(require 'org-tempo)

;; Capture from clipboard
(straight-use-package 'org-cliplink)

;; Open link in the same frame
(setq org-link-frame-setup
      '((vm . vm-visit-folder-other-frame)
        (vm-imap . vm-visit-imap-folder-other-frame)
        (gnus . org-gnus-no-new-news)
        (file . find-file)
        (wl . wl-other-frame)))

;; Improve org mode looks
(setq
 org-startup-indented t
 org-startup-truncated t
 org-hide-emphasis-markers t
 org-startup-with-inline-images t
 org-image-actual-width '(400))


(straight-use-package 'writeroom-mode)
(setq writeroom-fullscreen-effect nil)
(setq writeroom-width 90)

(straight-use-package 'org-superstar)
(straight-use-package 'org-appear)
(straight-use-package 'org-fragtog)
(straight-use-package 'org-pretty-tags)
(straight-use-package 'olivetti)

(defun my-org-mode-hook ()
  (org-indent-mode)
  (org-superstar-mode)
  (org-appear-mode) ;; Show emphasis markers only on mouse hover
  (org-fragtog-mode) ;; Show latex fragments on mouse hover
  (org-pretty-tags-mode) ;; Show tags in a pretty way
  (text-scale-set 2) ;; Increase font size
  (olivetti-mode)) 
(add-hook 'org-mode-hook 'my-org-mode-hook)

;; Org-babel

(straight-use-package 'ob-go)

;; Typescript
(straight-use-package 'ob-typescript)

(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (python . t)
   (go . t)
   (typescript . t)
   (js . t)
   (shell . t)
   (plantuml . t)
   (dot . t)
   (ditaa . t)
   (org . t)))

(when (eq place-is-open t)
  (setq org-attach-id-dir (concat SAFE_PLACE "/files/attachments/"))
  (setq org-directory (concat SAFE_PLACE "/emacs-org/"))

  (setq org-todo-keywords
        '((sequence
           "TODO(t)"
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

;;
;; Org-Roam
;;

(straight-use-package 'emacsql-sqlite3)
(straight-use-package 'org-roam)
(setq org-roam-completion-everywhere t)

; Search
(straight-use-package 'deft)

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

  (org-roam-db-autosync-mode 1)


  ;;
  ;; Agenda
  ;;

  (defun my/org-roam-filter-by-tag (tag-name)
    (lambda (node) (member tag-name (org-roam-node-tags node))))

  (defun my/org-roam-list-notes-by-tag (tag-name)
    (mapcar
     #'org-roam-node-file
     (seq-filter
      (my/org-roam-filter-by-tag tag-name) (org-roam-node-list))))

  (defun my/org-update-agenda-files ()
    (interactive)
    ;; Add to agenda only files with tag Board:
    (setq org-agenda-files (my/org-roam-list-notes-by-tag "Board"))
    (add-to-list 'org-agenda-files "~/Sync/Shared org/")
    (add-to-list 'org-agenda-files (concat SAFE_PLACE "/emacs-org/")))

  ;; Update agenda file-list for new session
  (my/org-update-agenda-files)


  ;; format: off
  (use-package org-roam-ui
     :straight
       (:host github :repo "org-roam/org-roam-ui" :branch "main" :files ("*.el" "out"))
       :after org-roam
       ;; normally we'd recommend hooking orui after org-roam, but since org-roam does not have
       ;; a hookable mode anymore, you're advised to pick something yourself
       ;; if you don't care about startup time, use
       ;; :hook (after-init . org-roam-ui-mode)
       :config
       (setq org-roam-ui-sync-theme t
             org-roam-ui-follow t
             org-roam-ui-update-on-save t
             org-roam-ui-open-on-start t))
  ;; format: on

  ;; Org-roam search with Deft (https://www.orgroam.com/manual.html#Full_002dtext-search-with-Deft)
  (setq deft-use-filter-string-for-filename t)
  (setq deft-directory org-roam-directory)
  (setq deft-recursive t)
  (setq deft-strip-summary-regexp
        (concat
         "\\("
         "^:.+:.*\n" ; any line with a :SOMETHING:
         "\\|^#\\+.*\n" ; anyline starting with a #+
         "\\|^\\*.+.*\n" ; anyline where an asterisk starts the line
         "\\)"))

  (advice-add
   'deft-parse-title
   :override
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
;; Auto-save
;;

(setq auto-save-visited-mode t)
(setq auto-save-default t)

(defun save-all ()
  (interactive)
  (save-some-buffers t)
  (message "All Saved"))

(add-function :after after-focus-change-function 'save-all)

;;
;; Spellcheck
;;

(straight-use-package 'flyspell)
(add-hook 'org-mode-hook 'flyspell-mode)
(add-hook 'text-mode-hook 'flyspell-mode)
(add-hook 'prog-mode-hook 'flyspell-prog-mode)

(with-eval-after-load "ispell"
  ;; Configure `LANG`, otherwise ispell.el cannot find a 'default
  ;; dictionary' even though multiple dictionaries will be configured
  ;; in next line.
  (setenv "LANG" "en_US.UTF-8")
  (setq ispell-program-name "hunspell")
  ;; Configure German, Swiss German, and two variants of English.
  (setq ispell-dictionary "en_GB,en_US,ru_RU")
  ;; ispell-set-spellchecker-params has to be called
  ;; before ispell-hunspell-add-multi-dic will work
  (ispell-set-spellchecker-params)
  (ispell-hunspell-add-multi-dic "en_GB,en_US,ru_RU")

  (when (eq place-is-open t)
    (setq ispell-personal-dictionary
          (concat SAFE_PLACE "/files/hunspell-dictionary.txt"))))

; Keybindings / Shortcuts

(straight-use-package 'which-key)
(setq which-key-idle-secondary-delay 0.02)
(which-key-mode 1)

(straight-use-package 'general)

(general-create-definer
 space-leader-def
 :keymaps 'override
 :prefix "SPC"
 :global-prefix "C-SPC")

(defun delete-file-and-close-buffer ()
  "Delete the current file and close the buffer."
  (interactive)
  (let ((filename (buffer-file-name)))
    (if (and filename (file-exists-p filename))
        (when (yes-or-no-p
               (format "Are you sure you want to delete %s? "
                       filename))
          (delete-file filename)
          (kill-buffer))
      (message "No file is associated with this buffer."))))


(defun launch-separate-emacs-in-terminal ()
  (suspend-emacs "fg ; emacs -nw"))

(defun launch-separate-emacs-under-x ()
  (call-process "sh" nil nil nil "-c" "emacs &"))

(defun restart-emacs ()
  (interactive)
  ;; We need the new emacs to be spawned after all kill-emacs-hooks
  ;; have been processed and there is nothing interesting left
  (let ((kill-emacs-hook
         (append
          kill-emacs-hook
          (list
           (if (display-graphic-p)
               #'launch-separate-emacs-under-x
             #'launch-separate-emacs-in-terminal)))))
    (save-buffers-kill-emacs)))

(defun lt/eshell-pop-show (name)
  "Create a pop up window with eshell named NAME."
  (let\* ((window (split-window
                  (frame-root-window)
                  '30
                  'below))
         (buffer (get-buffer name)))
    ;; make sure we are on the current window (pop-up)
    (select-window window)
    (if buffer
        (set-window-buffer window name)
      (progn
        (eshell window)
        (rename-buffer name)))
    ))

(defun lt/eshell-pop-hide (name)
  "Hide the existing pop up window with eshell named NAME."
  (let ((shell-buffer (get-buffer-window name)))
    (select-window shell-buffer)
    (bury-buffer)
    (delete-window)))

(defun toggle-shell-buffer ()
  "Toggle eshell pop up window."
  (interactive)
  (let ((name "shell-buffer"))
    (if (get-buffer-window name)
        (lt/eshell-pop-hide name)
      (lt/eshell-pop-show name))
    ))

(defun my/org-roam-node-find ()
  (interactive)
  (unwind-protect
;; unwind-protect is required to turn off ivy
;; even when you cancel without choosing a node
      (progn
       (ivy-mode +1)
       (org-roam-node-find))  
    (ivy-mode -1)))

(defun my/org-roam-node-insert ()
  (interactive)
  (unwind-protect
;; unwind-protect is required to turn off ivy
;; even when you cancel without choosing a node
      (progn
       (ivy-mode +1)
       (org-roam-node-insert))
    (ivy-mode -1)))

;; format: off
(space-leader-def
 :states '(normal visual)

 "b" '(:ignore t :which-key "buffer")
 "bb" '(switch-to-buffer :which-key "switch to buffer")
 "bd" '(kill-buffer :which-key "kill buffer")
 "bD" '(kill-some-buffers :which-key "kill some buffers")
 "be" '(eval-buffer :which-key "eval buffer")

 "w" '(:ignore t :which-key "window")
 "ws" '(split-window-below :which-key "split window below")
 "wv" '(split-window-right :which-key "split window right")
 "w=" '(balance-windows :which-key "balance windows")
 "wk" '(evil-window-up :which-key "move window up")
 "wj" '(evil-window-down :which-key "move window down")
 "wh" '(evil-window-left :which-key "move window left")
 "wl" '(evil-window-right :which-key "move window right")
 "wK" '(evil-window-decrease-height :which-key "decrease window height")
 "wJ" '(evil-window-increase-height :which-key "increase window height")
 "wH" '(evil-window-decrease-width :which-key "decrease window width")
 "wL" '(evil-window-increase-width :which-key "increase window width")
 "wd" '(delete-window :which-key "delete window")
 "wD" '(kill-buffer-and-window :which-key "kill buffer and window")

 "f" '(:ignore t :which-key "file")
 "ff" '(find-file :which-key "find file")
 "fs" '(save-all :which-key "save buffer")
 "fd" '(delete-file-and-close-buffer :which-key "delete file and close buffer")

 "t" '(:ignore t :which-key "tools")
 "tt" '(toggle-shell-buffer :which-key "toggle shell")
 "tz" '(writeroom-mode :which-key "writeroom mode")

 "n" '(:ignore t :which-key "org-roam")
 "nf" '(my/org-roam-node-find :which-key "find node")
 "ni" '(my/org-roam-node-insert :which-key "insert node")
 "nc" '(org-roam-capture :which-key "capture node")
 "nr" '(org-roam-buffer-toggle :which-key "toggle roam buffer")
 "nt" '(org-roam-tag-add :which-key "add tag")
 "nT" '(org-roam-tag-remove :which-key "remove tag")
 "nd" '(deft :which-key "open deft")
 "nu" '(org-roam-ui-open :which-key "open ui")

 "g" '(:ignore t :which-key "git")
 "gg" '(magit :which-key "magit")
 "gs" '(magit-status :which-key "magit status")
 "gd" '(magit-diff :which-key "magit diff")
 "gl" '(magit-log :which-key "magit log")
 "gc" '(magit-commit :which-key "magit commit")
 "gp" '(magit-push :which-key "magit push")
 "gP" '(magit-pull :which-key "magit pull")
 "gb" '(magit-blame :which-key "magit blame")

 "s" '(:ignore t :which-key "spell")
 "sc" '(ispell-word :which-key "check word")
 "sb" '(ispell-buffer :which-key "check buffer")
 "sr" '(ispell-region :which-key "check region")
 "sa" '(flyspell-auto-correct-word :which-key "auto correct word")

 "e" '(:ignore t :which-key "emacs")
 "ei" '(lambda () (interactive) (find-file user-init-file) :which-key "open init file")

 "p" '(:ignore t :which-key "project")
 "/" '(helm-projectile :which-key "find file")
 "." '(helm-projectile-grep :which-key "find file")
 "pp" '(projectile-switch-project :which-key "switch project")
 "pa" '(projectile-add-known-project :which-key "add known project")
 "pd" '(projectile-dired :which-key "dired")
 "pb" '(projectile-switch-to-buffer :which-key "switch to buffer")
 "pr" '(projectile-recentf :which-key "recent files")
 "ps" '(projectile-save-project-buffers :which-key "save project buffers")
 "pk" '(projectile-kill-buffers :which-key "kill project buffers")

 "N" '(neotree-toggle :which-key "toggle neotree")

 "q" '(:ignore t :which-key "quit")
 "qq" '(save-buffers-kill-terminal :which-key "quit emacs")
 "qQ" '(kill-emacs :which-key "kill emacs")
 "qr" '(restart-emacs :which-key "restart emacs"))
;; format: on

;; Org-mode only keybindings
(general-create-definer
 org-leader-def
 :keymaps 'org-mode-map
 :prefix "SPC o"
 :global-prefix "C-SPC")

;; format: off
(org-leader-def
 "" '(nil :which-key "org-mode")
 :states '(normal)

 "a" '(org-agenda :which-key "org agenda")
 "A" '(org-attach :which-key "org attach")
 "c" '(org-capture :which-key "org capture")
 "b" '(org-insert-structure-template :which-key "org insert structure template")

 "l" '(:ignore t :which-key "org links")
 "ls" '(org-store-link :which-key "org store link")
 "ll" '(org-insert-link :which-key "org insert link")
 "li" '(org-insert-stored-link :which-key "org insert stored link")
 "lc" '(org-cliplink :which-key "org clip link")

 "t" '(org-todo :which-key "org todo")
 "p" '(org-priority :which-key "org priority")

 "s" '(:ignore t :which-key "org time")
 "ss" '(org-schedule :which-key "org schedule")
 "sd" '(org-deadline :which-key "org deadline")
 "st" '(org-time-stamp :which-key "org time stamp")
 "sT" '(org-time-stamp-inactive :which-key "org time stamp inactive")
 "sr" '(org-time-stamp :which-key "org time stamp range")
 "sR" '(org-time-stamp-inactive :which-key "org time stamp range inactive"))
;; format: on

;; NeoTree can be opened (toggled) at projectile project root
(defun neotree-project-dir ()
    "Open NeoTree using the git root."
    (interactive)
    (let ((project-dir (projectile-project-root))
          (file-name (buffer-file-name)))
      (neotree-toggle)
      (if project-dir
          (if (neo-global--window-exists-p)
              (progn
                (neotree-dir project-dir)
                (neotree-find file-name)))
        (message "Could not find git project root."))))

(global-set-key (kbd "C-c C-p") 'neotree-project-dir)

;; Open links with RET in org-mode
(evil-define-key 'normal org-mode-map (kbd "RET") 'org-open-at-point)

;; Vim-like navigation in ido
(defun ido-my-keys ()
  (define-key ido-completion-map (kbd "C-k") 'ido-prev-match)
  (define-key ido-completion-map (kbd "C-j") 'ido-next-match))
(add-hook 'ido-setup-hook 'ido-my-keys)

;; Vim-like navigation in ivy
(defun ivy-my-keys ()
  (define-key ivy-minibuffer-map (kbd "C-k") 'ivy-previous-line)
  (define-key ivy-minibuffer-map (kbd "C-j") 'ivy-next-line))
(add-hook 'ivy-mode-hook 'ivy-my-keys)

;; Vim like navigation in helm
(define-key helm-map (kbd "C-j") 'helm-next-line)
(define-key helm-map (kbd "C-k") 'helm-previous-line)

;; Vim-like navigation in Agenda
(defun org-agenda-my-keys ()
  (define-key org-agenda-mode-map (kbd "k") 'org-agenda-previous-line)
  (define-key org-agenda-mode-map (kbd "j") 'org-agenda-next-line)
  (define-key org-agenda-mode-map (kbd "C-k") 'org-agenda-previous-item)
  (define-key org-agenda-mode-map (kbd "C-j") 'org-agenda-next-item)
  (define-key org-agenda-mode-map (kbd "C-l") 'org-agenda-later)
  (define-key org-agenda-mode-map (kbd "C-h") 'org-agenda-earlier))
(add-hook 'org-agenda-mode-hook 'org-agenda-my-keys)

;; TODO:
;; Why the hell I have so many completion frameworks?

;; Default file to open:
(find-file "~/.config/emacs/init.el")
