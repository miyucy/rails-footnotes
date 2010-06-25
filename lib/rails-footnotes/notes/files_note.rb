require 'rails-footnotes/notes/abstract_note'

module Footnotes
  module Notes
    class FilesNote < AbstractNote
      def initialize(controller)
        @files = scan_text(controller.response.body)
        parse_files!
      end

      def content
        if @files.empty?
          ""
        else
          "<ul><li>#{@files.join('</li><li>')}</li></ul>"
        end
      end

      protected
      def scan_text(text)
        []
      end

      def parse_files!
        @files.collect! do |filename|
          %[<a href="#{filename}">#{filename}</a>]
        end
      end
    end
  end
end
