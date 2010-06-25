require 'rails-footnotes/notes/abstract_note'

module Footnotes
  module Notes
    class LayoutNote < AbstractNote
      def initialize(controller)
        @controller = controller
      end

      def content
        "<ul><li>#{filename}</li></ul>"
      end

      def valid?
        @controller.active_layout
      end

      protected
      def filename
        File.join(Rails.root, 'app', 'layouts', "#{@controller.active_layout.to_s.underscore}").sub('/layouts/layouts/', '/views/layouts/')
      end
    end
  end
end
