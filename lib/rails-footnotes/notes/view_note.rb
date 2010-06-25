require 'rails-footnotes/notes/abstract_note'

module Footnotes
  module Notes
    class ViewNote < AbstractNote
      def initialize(controller)
        @controller = controller
        @template = controller.instance_variable_get(:@template)
      end

      def content
        "<ul><li>#{filename}</li></ul>"
      end

      def valid?
        first_render?
      end

      protected

      def first_render?
        @template.instance_variable_get(:@_first_render)
      end

      def filename
        @filename ||= @template.instance_variable_get(:@_first_render).filename
      end

    end
  end
end
