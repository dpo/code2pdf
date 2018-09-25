class ConvertToPDF

  def initialize(params = {})
    if !params.key?(:from) || params[:from].nil?
      raise ArgumentError.new 'where is the codebase you want to convert to PDF?'
    elsif !valid_directory?(params[:from])
      raise LoadError.new "#{params[:from]} not found"
    elsif !params.key?(:to) || params[:to].nil?
      raise ArgumentError.new 'where should I save the generated pdf file?'
    else
      @from, @to, @except = params[:from], params[:to], params[:except].to_s

      if File.exist?(@except) && invalid_blacklist?
        raise LoadError.new "#{@except} is not a valid blacklist YAML file"
      end

      save
    end
  end

  private

  def save
    pdf.to_file(@to)
  end

  def pdf
    html ||= ''

    style = 'font-size: 12px; font-family: Courier'

    read_files.each do |file|
      html += "<strong style='#{style}'>File: #{file.first}</strong></br></br>"
      html += prepare_line_breaks(syntax_highlight(file)).to_s
      html += add_space(30)
    end

    PDFKit.configure do |config|
    config.default_options = {
        page_size: 'Letter',
        print_media_type: true,
        dpi: 400,
        margin_top: '0.5in',
        margin_left: '0.5in',
        margin_bottom: '0.5in',
        margin_right: '0.5in'
    }
    end

    @kit = PDFKit.new(html)
    @kit
  end

  def syntax_highlight(file)
    file_type = File.extname(file.first)[1..-1]
    file_lexer = Rouge::Lexer.find(file_type)
    return file.last unless file_lexer

    theme = Rouge::Themes::Github  #.mode(:light)
    formatter = Rouge::Formatters::HTMLInline.new(theme)
    formatter = Rouge::Formatters::HTMLTable.new(formatter, start_line: 1)
    formatter.format(file_lexer.lex(file.last))
  end

  def invalid_blacklist?
    return true if FileTest.directory?(@except)

    @blacklist = YAML.load_file(@except)

    !@blacklist.key?(:directories) || !@blacklist.key?(:files)
  end

  def in_directory_blacklist?(item_path)
    @blacklist[:directories].include?(item_path.gsub("#{@from}/", '')) if @blacklist
  end

  def in_file_blacklist?(item_path)
    if @blacklist
      @blacklist[:files].include?(item_path.split('/').last) || @blacklist[:files].include?(item_path.gsub("#{@from}/", ''))
    end
  end

  def valid_directory?(dir)
    File.exist?(dir) && FileTest.directory?(dir)
  end

  def valid_file?(file)
    File.exist?(file) && FileTest.file?(file)
  end

  def read_files(path = nil)
    @files ||= []
    path   ||= @from

    Dir.foreach(path) do |item|
      item_path = "#{path}/#{item}"

      if valid_directory?(item_path) && !%w[. ..].include?(item) && !in_directory_blacklist?(item_path)
        read_files(item_path)
      elsif valid_file?(item_path) && !in_file_blacklist?(item_path)
        @files << [item_path, process_file(item_path)]
      end
    end

    @files
  end

  def process_file(file)
    puts "Reading file #{file}"

    content = ''
    File.open(file, 'r') do |f|
      if `file #{file}` !~ /text/
        content << "<color rgb='777777'>[binary]</color>"
      else
        f.each_line { |line_content| content << line_content }
      end
    end
    content
  end

  def prepare_line_breaks(content)
    content.gsub(/\n/, '<br>')
  end

  def add_space(height)
    "<div style='margin-bottom: #{height}px'>&nbsp;</div>"
  end
end
