module Footnotes
  class Filter
    @@klasses = []

    # Show notes
    @@notes = [ :controller, :view, :layout, :partials, :stylesheets, :javascripts,
                :assigns, :session, :cookies, :params, :filters, :routes, :env, :queries,
                :log, :general, ]

    # Change queries for rpm note when available
    # if defined?(NewRelic)
    #  @@notes.delete(:queries)
    #  @@notes << :rpm
    # end

    # :notes          => Class variable that holds the notes to be processed
    cattr_accessor :notes

    class << self
      # Method called to start the notes
      # It's a before filter prepend in the controller
      #
      def before(controller)
        Footnotes::Filter.start!(controller)
      end

      # Method that calls Footnotes to attach its contents
      #
      def after(controller)
        filter = Footnotes::Filter.new(controller)
        filter.add_footnotes!
        filter.close!(controller)
      end

      # Calls the class method start! in each note
      # Sometimes notes need to set variables or clean the environment to work properly
      # This method allows this kind of setup
      #
      def start!(controller)
        @@klasses = []

        each_with_rescue(@@notes.flatten) do |note|
          klass = "Footnotes::Notes::#{note.to_s.camelize}Note".constantize
          klass.start!(controller) if klass.respond_to?(:start!)
          @@klasses << klass
        end
      end

      # Process notes, discarding only the note if any problem occurs
      #
      def each_with_rescue(notes)
        delete_me = []

        notes.each do |note|
          begin
            yield note
          rescue Exception => e
            # Discard note if it has a problem
            log_error("Footnotes #{note.to_s.camelize}Note Exception", e)
            delete_me << note
            next
          end
        end

        delete_me.each{ |note| notes.delete(note) }
        return notes
      end

      # Logs the error using specified title and format
      #
      def log_error(title, exception)
        Rails.logger.error "#{title}: #{exception}\n#{exception.backtrace.join("\n")}"
      end

    end

    def initialize(controller)
      @controller = controller
      @template = controller.instance_variable_get(:@template)
      @body = controller.response.body
      @notes = []
    end

    def add_footnotes!
      add_footnotes_without_validation! if valid?
    rescue Exception => e
      # Discard footnotes if there are any problems
      self.class.log_error("Footnotes Exception", e)
    end

    # Calls the class method close! in each note
    # Sometimes notes need to finish their work even after being read
    # This method allows this kind of work
    #
    def close!(controller)
      each_with_rescue(@@klasses) do |klass|
        klass.close!(controller)
      end
    end

    protected

    def add_footnotes_without_validation!
      initialize_notes!
      insert_popup
    end

    def initialize_notes!
      each_with_rescue(@@klasses) do |klass|
        note = klass.new(@controller)
        @notes << note if note.respond_to?(:valid?) && note.valid?
      end
    end

    def valid?
      (
       @body.is_a?(String) &&
       performed_render? &&
       valid_format? &&
       valid_content_type? &&
       !component_request? &&
       !xhr? &&
       !footnotes_disabled? &&
       !mobile? &&
       !oauth_verified?
       )
    end

    def performed_render?
      @controller.instance_variable_get(:@performed_render)
    end

    def valid_format?
      [:html,:rhtml,:xhtml,:rxhtml].include?(@template.template_format.to_sym)
    end

    def valid_content_type?
      @controller.response.content_type.empty? || @controller.response.content_type =~ /html/
    end

    def component_request?
      @controller.instance_variable_get(:@parent_controller)
    end

    def xhr?
      @controller.request.xhr?
    end

    def footnotes_disabled?
      @controller.params[:footnotes] == "false"
    end

    def mobile?
      (@controller.request.respond_to?(:mobile?) &&
       @controller.request.mobile? &&
       @controller.request.mobile.valid_ip?)
    end

    def oauth_verified?
      (@controller.request.respond_to?(:oauth_verified?) &&
       @controller.request.oauth_verified?)
    end

    #
    # Insertion methods
    #

    def insert_popup
      content = ""
      popup_html.each_line do |line|
        snippet = line.gsub(%r("), %q(\\")).gsub(%r(</), %q(<"+"/)).rstrip
        content << "w.document.write(\"#{snippet}\\n\");"
      end

      insert_text :before, %r(</body>)i, <<-HTML
<script type="text/javascript"><!--
(function(){
w = window.open("","#{@controller.class.name}","width=640,height=480,resizable,scrollerbars=yes");
#{content}
w.document.close();
})();
--></script>
      HTML
    end

    def popup_html
      <<-HTML
<html>
<head>
<title>#{@controller.class.name}</title>
#{popup_styles}
</head>
<body>
#{popup_bodies}
</div>
</body>
</html>
      HTML
    end

    def popup_styles
      <<-CSS
<style type="text/css">
  #footnotes_debug {margin: 2em 0 1em 0; text-align: center; color: #444; line-height: 16px;}
  #footnotes_debug th, #footnotes_debug td {color: #444; line-height: 18px;}
  #footnotes_debug a {text-decoration: none; color: #444; line-height: 18px;}
  #footnotes_debug table {text-align: center;}
  #footnotes_debug table td {padding: 0 5px;}
  #footnotes_debug tbody {text-align: left;}
  #footnotes_debug .name_values td {vertical-align: top;}
  #footnotes_debug legend {background-color: #FFF;}
  #footnotes_debug fieldset {text-align: left; border: 1px dashed #aaa; padding: 0.5em 1em 1em 1em; margin: 1em 2em; color: #444; background-color: #FFF;}
  /* Aditional Stylesheets */
  #{@notes.map(&:stylesheet).compact.join("\n")}
</style>
      CSS
    end

    def popup_bodies
      content = fieldsets
      <<-HTML
<div id="footnotes_debug">
#{links}
#{content}
</div>
      HTML
    end

    # Process notes to gets their links in their equivalent row
    #
    def links
      links = Hash.new([])
      order = []
      each_with_rescue(@notes) do |note|
        order << note.row
        links[note.row] += [link_helper(note)]
      end

      html = ''
      order.uniq!
      order.each do |row|
        html << "#{row.is_a?(String) ? row : row.to_s.camelize}: #{links[row].join(" | \n")}<br />"
      end
      html
    end

    # Process notes to get their content
    #
    def fieldsets
      content = ''
      each_with_rescue(@notes) do |note|
        next unless note.has_fieldset?
        content << <<-HTML
<fieldset id="#{note.to_sym}_debug_info">
  <legend>#{note.legend}</legend>
  <div>#{note.content}</div>
</fieldset>
        HTML
      end
      content
    end

    #
    # Helpers
    #

    # Helper that creates the link and javascript code when note is clicked
    #
    def link_helper(note)
      href   = note.link
      href ||= "##{note.to_sym}_debug_info"

      onclick = note.onclick
      onclick = %(onclick="#{onclick}") if onclick

      %(<a href="#{href}" #{onclick}>#{note.title}</a>)
    end

    # Inserts text in to the body of the document
    # +pattern+ is a Regular expression which, when matched, will cause +new_text+
    # to be inserted before or after the match.  If no match is found, +new_text+ is appended
    # to the body instead. +position+ may be either :before or :after
    #
    def insert_text(position, pattern, new_text)
      index = case pattern
              when Regexp
                if match = @body.match(pattern)
                  match.offset(0)[position == :before ? 0 : 1]
                else
                  @body.size
                end
              else
                pattern
              end
      @body.insert index, new_text
    end

    # Instance each_with_rescue method
    #
    def each_with_rescue(*args, &block)
      self.class.each_with_rescue(*args, &block)
    end

  end
end
