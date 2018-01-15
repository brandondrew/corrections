require 'tty'
require 'tty-table'
require 'encoding_sampler'
require 'active_support/inflector'

class InvalidPath < RuntimeError; end
class BinaryFile < RuntimeError; end
class UnknownFileEncoding < RuntimeError; end

class App
  def initialize
    define_styles
    @shell = TTY::Prompt.new
    @default_prompt = @in_color.green.on_black('>: ')
    @possible_encodings = ['UTF-8', 'ASCII-8BIT', 'ISO-8859-1', 'ISO-8859-2', 'ISO-8859-15']
    @encoding_hint = ''
    @system = TTY::Command.new(printer: :null)
    @key_collisions = []
    @last_collision_candidate = ''
    @spinner = TTY::Spinner.new(":spinner Generating your autocorrection set... :spinner", format: :arrow_pulse)
end

  def define_styles
    @in_color = Pastel.new
    @action_style = proc { |input| @in_color.green.on_black(input) }
    @danger_style = proc { |input| @in_color.red.on_black(input) }
    @info_style   = proc { |input| @in_color.white.on_black(input) }
  end

  def inferred_encoding
    @inferred_encoding ||= begin
      sampler = EncodingSampler::Sampler.new(file_location, sorted_encodings)
      # surprise: EncodingSampler changes @sorted_encodings! 😱
      puts @action_style.call 'Please choose correct encodings of the file.'
      choices = {}
      sorted_encodings.each do |encoding|
        choices["#{encoding}: #{sampler.sample(encoding).inspect}"] = encoding
      end
      @shell.select((@action_style.call 'Choose the first text sample that looks correct.'), choices, echo: false)
    end
  end

  def native_word_list
    @native_word_list ||= begin
      path = '/usr/share/dict/web2'
      if File.file?(path)
        path
      else
        puts @action_style.call 'Please enter file path to an English word list:'
        @shell.ask(@default_prompt, default: path)
      end
    end
  end

  def english_has(word)
    @system.run!('grep', '-x', word, native_word_list).success?
  end

  def word_list_has(word)
    @system.run!('grep', '-x', word, @file_location).success?
  end

  def collision_list
    @collision_list ||= begin
      dupes = []
      word_list = get_word_list # no memoization because we need 2 independent variables
      word_list.each_line do |word|
        word_without_diacritics = ActiveSupport::Inflector.transliterate(word).chomp
        dupes << word_without_diacritics if word_without_diacritics == @last_collision_candidate
        @last_collision_candidate = word_without_diacritics
      end
      dupes
    end
  end

  def collides(word)
    collision_list.include? word
  end

  def valid_correction(word_without_diacritics, word)
    # skip words in the collision list
    return false if collides(word_without_diacritics)
    # skip words without diacritics
    return false if word == word_without_diacritics
    # skip if non-diacritical version is another word
    return false if word_list_has(word_without_diacritics)
    # skip English words
    return false if english_has(word_without_diacritics)
    true
  end

  def base_file_path
    File.join(Dir.pwd, File.basename(file_location, '.*'))
  end

  def autocorrect_file
    @autocorrect_file ||= File.open(base_file_path + '_Autocorrect.csv', 'w')
  end

  def generate_correction_list
    word_list = get_word_list
    word_list.each_line do |word|
      generate_correction_entry(word)
    end
    word_list.close
  end

  def generate_correction_entry(word)
    word = enforce_encoding(word)
    word_without_diacritics = ActiveSupport::Inflector.transliterate(word)
    if valid_correction(word_without_diacritics, word)
      display_time_notice_once unless @time_notice_displayed
      autocorrect_file.write "#{word_without_diacritics},#{word},match,whole\n"
      @last_word = {word_without_diacritics: word_without_diacritics, word: word }
    end
  end

  def enforce_encoding(word)
    word = word.chomp.force_encoding(inferred_encoding).encode('utf-8')
  rescue Encoding::UndefinedConversionError
    puts @danger_style.call 'That encoding blew up in your face.  Please try a different one.'
    exit 1
  end

  def run
    generate_correction_list if collision_list
  end

  def display_time_notice_once
    puts @info_style.call 'This may take a minute for large word lists... ☕'
    @spinner.auto_spin
    @time_notice_displayed = true
  end

  def display_wrap_up_message
    puts @info_style.call "You can now import #{autocorrect_file} into Typinator."
  end

  def file_location
    @file_location ||= begin
      puts @info_style.call 'You will need a word list or spelling dictionary as a source file.'
      puts @info_style.call 'The file should contain one word per line, sorted alphabetically.'
      puts @info_style.call 'This is a common format for word processor spelling dictionaries.'
      puts @action_style.call 'Please enter file path to your word list:'
      @shell.ask(@default_prompt, default: './samples/sample.dic')
    end
  end

  def get_word_list
    if File.file?(file_location)
      File.open(file_location, 'r')
    else
      raise InvalidPath
    end
  rescue InvalidPath
    puts @danger_style.call('Invalid path: you need to supply a valid path to a word list.')
    exit 2
  end

  def sorted_encodings
    @sorted_encodings ||= begin
      result = @system.run!('file', '--brief', '--keep-going', file_location)
      if result.failure?
        puts @danger_style.call 'Your system returned an error.  You may lack /usr/bin/file.'
        # things will still work without /usr/bin/file
      else
        if result.out.match?(/(binary|data)/)
          raise BinaryFile, @danger_style.call("Binary File: we can't parse binary files.")
        elsif result.out.match?(/text/)
          @encoding_hint = result.out.gsub(' text','').chomp
          @most_likely_encodings = @possible_encodings.select do |encoding|
            encoding =~ /#{@encoding_hint}/
          end
          @sorted_encodings = (@most_likely_encodings + @possible_encodings).uniq
        else
          raise UnknownFileEncoding\
          , @danger_style.call("Unknown File Encoding: we can't determine what kind of file this is....")
        end
      end
      @sorted_encodings ||= @possible_encodings
    end
  end
end

App.new.run
