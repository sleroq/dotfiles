local status, orgmode = pcall(require, 'orgmode')
if (not status) then return end

local safe_place = os.getenv('SAFE_PLACE')

orgmode.setup_ts_grammar()

orgmode.setup({
  org_agenda_files = safe_place .. 'emacs-org/*',
  org_default_notes_file = safe_place .. 'emacs-org/general-journal.org'
})
