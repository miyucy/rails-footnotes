require 'rails-footnotes/notes/abstract_note'

module Footnotes
  module Notes
    class ControllerNote < AbstractNote
      def initialize(controller)
        @controller = controller
      end

      def content
        "<ul><li>#{controller_filename}</li></ul>"
      end

      protected
      # Some controller classes come with the Controller:: module and some don't
      # (anyone know why? -- Duane)
      def controller_filename
        controller_name = @controller.class.to_s.underscore
        if ActionController::Routing.respond_to? :controller_paths
          controller_filename = nil
          ActionController::Routing.controller_paths.each do |controller_path|
            full_controller_path = File.join(File.expand_path(controller_path), "#{controller_name}.rb")
            controller_filename  = full_controller_path if File.exists?(full_controller_path)
          end
        else
          controller_filename = File.join(Rails.root, 'app', 'controllers', "#{controller_name}.rb").sub('/controllers/controllers/', '/controllers/')
        end
        controller_filename
      end
    end
  end
end
