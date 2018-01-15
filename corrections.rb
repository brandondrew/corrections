require 'tty'
require 'tty-table'
require 'encoding_sampler'
require "active_support/inflector"
require "pry"
# TODO: look at https://github.com/brianmario/charlock_holmes to replace or augment `file --brief`

# I'm going to go with Avdi's philosophy of OO, and not turn everything into Service Objects.
# I'm also going to use minitest for simplicity (& to try something new, as I normally use Rspec).
# I'm *also* going to embed test code & comments in my initial sketches, and reorganize later.


# steps:
# 1 get the list based on user input
# 2 determine the proper file encoding
# 3 normalize the file encoding
# 4 ensure it has a usable format
# 5 verify English as user's native language
# 6 find words with diacritics
# 7 check each of these against a list of English words
# 8 check for a non-diacritic version in the target language
# 9 check for duplicates of non-diacritic versions in target language (atém and atêm both have atem)


# catch Encoding::UndefinedConversionError

class App
  def initialize
    @shell = TTY::Prompt.new
    @default_prompt = '>: '
    @in_color = Pastel.new
    @possible_encodings = ['UTF-8', 'ASCII-8BIT', 'ISO-8859-1', 'ISO-8859-2', 'ISO-8859-15']
    @encoding_hint = ''
    @command = TTY::Command.new(printer: :null)
    @last_ten_words = [] # @last_ten_words = (@last_ten_words << new_word).take(10)
    @fixed_words = [] # inspect them later to verify the encoding
    # @last_word = {}
    @key_collisions = []
  end
  
  def inferred_encoding
    @inferred_encoding ||= begin
      sampler = EncodingSampler::Sampler.new(file_location, sorted_encodings) # EncodingSampler changes @sorted_encodings! 😱
      puts @in_color.green.on_black "Please choose correct encodings of the file."
      choices = {}
      sorted_encodings.each do |encoding|
        choices["#{encoding}: #{sampler.sample(encoding).inspect}"] = encoding
      end
      choice = @shell.select((@in_color.green.on_black "Choose the first text sample that looks correct."), choices, echo: false)
      #choice = @shell.multi_select((@in_color.green.on_black "Please choose correct encodings of the file."), choices, echo: false)
    end
  end

  def native_word_list
    @native_word_list ||= begin
      path = '/usr/share/dict/web2'
      path if File.file?(path)
    end
  end
  
  # EXAMPLES 
  # ate,até     ← English word: skip it!
  # atem,atém and atêm   ← Duplicate Portuguese word: skip it, both have atem!

  def english_has(word)
    # TODO: verify this file at this location, or ask for a new path if it's not there
    @command.run!('grep', '-x', word, native_word_list).success?
    # opportunity for optimization
  end

  def word_list_has(word)
    @command.run!('grep', '-x', word, @file_location).success?
  end

  def collision_list
    @collision_list ||= ['ate','atem'] # TODO: generate this with a first pass over the dictionary <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
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
    # skip if it's the same as the last word
    if @last_word # TODO: switch to shorthand syntax
      return false if @last_word[:word_without_diacritics] == word_without_diacritics
    end
    return true
  end
  
  def run
    word_list.each_line do |word|
      # word = word.chomp
      original = word.chomp
      begin
        word = word.chomp.force_encoding(inferred_encoding).encode("utf-8") # TODO: benchmark memoized inferred_encoding versus local variable
      rescue Encoding::UndefinedConversionError
        puts "That encoding blew up in your face.  Please try a different one."
        break
      end
      word_without_diacritics = ActiveSupport::Inflector.transliterate(word)
      
      if original != word
        @fixed_words << word
      end
      
      # binding.pry unless pry == true
      # binding.pry if word_without_diacritics == 'atem'
      # unless collides(word_without_diacritics)
      # if @last_word
      #   if valid_correction(@last_word[:word_without_diacritics], @last_word[:word])
      #     puts "#{@last_word[:word_without_diacritics]},#{@last_word[:word]}" if @last_word
      #     @last_word = {word_without_diacritics: word_without_diacritics, word: word }
      #   end
      # else
      # puts word_without_diacritics
        if valid_correction(word_without_diacritics, word)
          puts "#{word_without_diacritics},#{word}"
          @last_word = {word_without_diacritics: word_without_diacritics, word: word }
        end
        # puts "#{word_without_diacritics},#{word}"
      # end
    end
    word_list.close
    # puts @fixed_words.inspect
  end

  def file_location
    @file_location ||= begin 
      puts @in_color.white.on_black 'You will need a word list or spelling dictionary as a source file.'
      puts @in_color.white.on_black 'The file should contain one word per line, sorted alphabetically.'
      puts @in_color.white.on_black 'This is a common format for word processor spelling dictionaries.'
      puts @in_color.green.on_black 'Please enter file path to your word list:'
      @shell.ask(@default_prompt, default: "sample.dic")
      # @shell.ask(@default_prompt, default: "Portuguese.dic")
    end
  end

  def word_list
    @word_list ||= if File.file?(file_location)
      File.open(file_location, 'r')
    else
      raise "Invalid location: you need to supply either a URI or a file path to a word list."
    end
  end

  def sorted_encodings
    @sorted_encodings ||= begin
      result = @command.run('file', '--brief', '--keep-going', file_location)
      if result.failure?
        puts in_color.red.on_black "Your system returned an error.  You may lack /usr/bin/file."
        # just keep going without using /usr/bin/file
      else
        # ensure that it's not binary
        if result.out =~ /(binary|data)/
          raise "Binary File: we can't parse binary files."
        elsif result.out =~ /text/
          @encoding_hint = result.out.gsub(' text','').chomp # << forgetting that CHOMP caused me so much pain 😱
          @most_likely_encodings = @possible_encodings.select {|encoding| encoding =~ /#{@encoding_hint}/}
          @sorted_encodings = (@most_likely_encodings + @possible_encodings).uniq # am I naive to assume the removal will be from the end?
          # I could do @most_likely_encodings + (@possible_encodings - @most_likely_encodings) if the above fails TODO: test assumption
        else
          raise "Unknown File Encoding: we can't determine what kind of file this is...."
        end
      end
      @sorted_encodings ||= @possible_encodings
    end
  end

  def ensure_not_binary

  end

  def determine_encoding

  end

  def normalize_encoding

  end

end

# yes it makes sense to use an object rather than a class:
# 1) we get the initialize method
# 2) who says we would never run two in parallel (after heavily modifying the interface)
App.new.run



