require 'rails-footnotes/notes/abstract_note'

module Footnotes
  module Notes
    class EnvNote < AbstractNote
      def initialize(controller)
        @env = controller.request.env.dup
      end

      def content
        env_data = @env.to_a.sort.unshift([:key, :value]).map do |k,v|
          case k
          when 'HTTP_COOKIE'
            # Replace HTTP_COOKIE for a link
            [k, %(<a href="#cookies_debug_info" style="color:#009;">See cookies on its tab</a>)]
          else
            [k, escape(v.to_s)]
          end
        end

        # Create the env table
        mount_table(env_data)
      end
    end
  end
end
