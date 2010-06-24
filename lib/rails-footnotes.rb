if Rails.env.development?
  require 'rails-footnotes/footnotes'

  # Load all notes
  #
  Dir[File.join(File.dirname(__FILE__), 'rails-footnotes', 'notes', '*.rb')].sort.each do |note|
    require 'rails-footnotes/notes/' + File.basename(note, '.rb')
  end

  # The footnotes are applied by default to all actions. You can change this
  # behavior commenting the after_filter line below and putting it in Your
  # application. Then you can cherrypick in which actions it will appear.
  #
  class ActionController::Base
    prepend_before_filter Footnotes::Filter
    after_filter Footnotes::Filter
  end
end
