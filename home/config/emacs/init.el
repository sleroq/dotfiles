(setq user-full-name "Sleroq"
      user-mail-address "cantundo@pm.me")

(setq undo-limit 50000000)
(setq SAFE_PLACE (getenv "SAFE_PLACE"))

(setq place-is-open (and (not (string-empty-p SAFE_PLACE)) (file-directory-p SAFE_PLACE)))

;
; Packages I guess:
;
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 6))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))
(setq package-enable-at-startup nil)

(straight-use-package 'use-package)
(straight-use-package 'org)

; Install evil-mode 
(setq evil-want-keybinding nil)
(straight-use-package 'evil)
(straight-use-package 'evil-collection)
(evil-collection-init)
(evil-mode 1)

(straight-use-package 'writeroom-mode)

; Look and feel
;

; Keyboard-centric user interface
(setq inhibit-startup-message t)
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode t)
(defalias 'yes-or-no-p 'y-or-n-p)

; Theme
(straight-use-package
 '(zeno-theme :type git :host github :repo "zenobht/zeno-theme"))
(load-theme 'zeno t)

; 
; Org-mode
;

; Open link in the same frame
(setq org-link-frame-setup
      '((vm . vm-visit-folder-other-frame)
        (vm-imap . vm-visit-imap-folder-other-frame)
        (gnus . org-gnus-no-new-news)
        (file . find-file) ; changed this line
        (wl . wl-other-frame)))

; Babel
(straight-use-package 'ob-go)

(org-babel-do-load-languages
 'org-babel-load-languages
 '((js . t)
   (go . t)
   (python . t)))

(when (eq place-is-open t)
  (setq org-attach-id-dir (concat SAFE_PLACE "/files/attachments/"))
  (setq org-directory (concat SAFE_PLACE "/emacs-org/"))
   ; (after! org
    (setq org-image-actual-width 600)
    (setq org-todo-keywords
      '((sequence "TODO(t)" "HOLD(h)" "IDEA(i)" "|" "DONE(d!)" "KILL(k!)" "NO(n!)")
        (sequence "[ ](T)" "[-](S)" "|" "[X](D)")))
     (setq org-todo-keyword-faces
      '(("IDEA" . (:foreground "brightcyan"))
        ("REVIEW" . (:foreground "#FDFD96")))) ;; pastel-yellow
     (setq org-log-done 'time););)
     (setq org-publish-project-alist (list
       (list "emacs-org"
           :recursive t
           :base-directory org-directory
           :publishing-directory (concat org-directory "public/")
           :exclude "public"
           :publishing-function 'org-html-publish-to-html
           :with-author nil
           :with-creator nil))))

(setq org-startup-with-inline-images t)

(setq writeroom-fullscreen-effect nil)
(add-hook 'org-mode-hook 'writeroom-mode)

(add-hook 'org-mode-hook
	  (lambda ()
	    (text-scale-set 2)))

; Default file to open:
(find-file "~/.config/emacs/init.el")

; Restore previos session
;   I need this just to preserve my command history.
;   TODO: Figure out how to do this without saving everything else
(desktop-save-mode 1)
(savehist-mode 1)
(add-to-list 'savehist-additional-variables 'kill-ring) ;; for example



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

;;
;; Org-Roam
;;

(straight-use-package 'emacsql-sqlite3)

(straight-use-package 'org-roam)

(straight-use-package 'deft)

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

    (org-roam-db-autosync-mode)


;   (use-package! websocket
;       :after org-roam)
; 
;   (use-package! org-roam-ui
;       :after org;; or :after org-roam
;   ;;  if you don't care about startup time, use
;   ;;  :hook (after-init . org-roam-ui-mode)
;       :config
;       (setq org-roam-ui-sync-theme t
;             org-roam-ui-follow t
;             org-roam-ui-update-on-save t
;             org-roam-ui-open-on-start t))
    
    ;; Update agenda file-list for new session
    (my/org-update-agenda-files)
    
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
;; Autosave
;;

(setq auto-save-visited-mode t)
(setq auto-save-default t)

(defun save-all ()
  (interactive)
  (save-some-buffers t))

(add-function :after after-focus-change-function 'save-all)

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


; Define the init file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
 (load custom-file))

; Font
(set-face-attribute 'default nil :font "JetBrainsMono Nerd Font" :height 140)

; Keybindings

(straight-use-package 'which-key)
(setq which-key-idle-secondary-delay 0.02)
(which-key-mode 1)

(defvar my-space-map (make-sparse-keymap)
  "Keymap for space-oriented keybindings.")

(define-key evil-normal-state-map (kbd "SPC") my-space-map)


(defvar my-space-b-map (make-sparse-keymap)
  "Sub-keymap for SPC b (buffer related).")

(define-key my-space-map (kbd "b") my-space-b-map)

(define-key my-space-b-map (kbd "q") 'kill-buffer)
(define-key my-space-b-map (kbd "b") 'switch-to-buffer)
(define-key my-space-b-map (kbd "e") 'eval-buffer)

(defvar my-space-w-map (make-sparse-keymap)
  "Sub-keymap for SPC w (window related).")

(define-key my-space-map (kbd "w") my-space-w-map)

(define-key my-space-w-map (kbd "q") 'kill-buffer-and-window)

(defvar my-space-f-map (make-sparse-keymap)
  "Sub-keymap for SPC f.")

(define-key my-space-map (kbd "f") my-space-f-map)

; (defun delete-if-file ()
;   (interactive)
;   (if (buffer-file-name)
;       (if (y-or-n-p (format "Delete file %s? " (buffer-file-name)))
;       (delete-file (buffer-file-name))
;       (message "File not deleted"))
;     (kill-buffer)))

; (defun delete-file-and-close-buffer ()
;   "Delete the current file and close the buffer."
;   (interactive)
;   (let ((filename (buffer-file-name)))
;     (if (and filename (file-exists-p filename))
;         (when (yes-or-no-p (format "Are you sure you want to delete %s? " filename))
;           (delete-file filename)
;           (kill-buffer))
;       (message "No file is associated with this buffer."))))

(defun delete-file-and-close-buffer ()
  "Delete the current file and close the buffer."
  (interactive)
  (let ((filename (buffer-file-name)))
    (if (and filename (file-exists-p filename))
        (when (yes-or-no-p (format "Are you sure you want to delete %s? " filename))
          (delete-file filename)
          (kill-buffer))
      (message "No file is associated with this buffer."))))

(define-key my-space-f-map (kbd "f") 'find-file)
(define-key my-space-f-map (kbd "s") 'save-all)
(define-key my-space-f-map (kbd "d") 'delete-file-and-close-buffer)

(straight-use-package 'neotree)
(define-key my-space-f-map (kbd "p") 'neotree-toggle)

(defvar my-space-r-map (make-sparse-keymap)
  "Sub-keymap for SPC f (for org-roam).")

(define-key my-space-map (kbd "r") my-space-r-map)

(define-key my-space-r-map (kbd "f") 'org-roam-node-find)
(define-key my-space-r-map (kbd "i") 'org-roam-node-insert)
(define-key my-space-r-map (kbd "c") 'org-roam-capture)
(define-key my-space-r-map (kbd "r") 'org-roam-buffer-toggle)
(define-key my-space-r-map (kbd "d") 'deft)

(defvar my-space-g-map (make-sparse-keymap)
  "Sub-keymap for SPC g (git).")

(define-key my-space-map (kbd "g") my-space-g-map)

(straight-use-package 'magit)
(define-key my-space-g-map (kbd "g") 'magit)

(defvar my-space-o-map (make-sparse-keymap)
  "Sub-keymap for SPC o (org-mode).")

(define-key my-space-map (kbd "o") my-space-o-map)

(defvar my-space-o-l-map (make-sparse-keymap)
  "Sub-keymap for SPC o t (org-mode).")

(define-key my-space-o-map (kbd "l") my-space-o-l-map)

(straight-use-package 'org-cliplink)
(define-key my-space-o-l-map (kbd "c") 'org-cliplink)
(define-key my-space-o-l-map (kbd "s") 'org-store-link)
(define-key my-space-o-l-map (kbd "i") 'org-insert-last-stored-link)
(define-key my-space-o-l-map (kbd "") 'org-insert-link)

(defvar my-space-o-t-map (make-sparse-keymap)
  "Sub-keymap for SPC o t (org-mode).")

(define-key my-space-o-map (kbd "t") my-space-o-t-map)

(define-key my-space-o-t-map (kbd "t") 'org-time-stamp)
(define-key my-space-o-t-map (kbd "i") 'org-time-stamp-inactive)
(define-key my-space-o-t-map (kbd "i") 'org-time-stamp-inactive)


(defvar my-space-q-map (make-sparse-keymap)
  "Sub-keymap for SPC q.")

(define-key my-space-map (kbd "q") my-space-q-map)

(define-key my-space-q-map (kbd "q") 'save-buffers-kill-terminal)

; Open links with Enter in org-mode
(evil-define-key 'normal org-mode-map (kbd "RET") 'org-open-at-point)
