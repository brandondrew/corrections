require 'tty'
require 'tty-table'
require 'encoding_sampler'
require 'pry'
# TODO: look at https://github.com/brianmario/charlock_holmes to replace or augment `file --brief`

# I'm going to go with Avdi's philosophy of OO, and not turn everything into Service Objects.
# I'm also going to use minitest for simplicity (& to try something new, as I normally use Rspec).
# I'm *also* going to embed test code & comments in my initial sketches, and reorganize later.

#require "minitest/autorun"

@in_color = Pastel.new

# methods:
#   fetch_word_list(location)
#   read_word_list(path)

# steps:
# 1 get the list based on user input
# 2 normalize the file encoding
# 3 ensure it has a usable format
# 4

class App # going with a generic name, since the user doesn't see this...

  def self.run

  end

  def self.get_word_list(location)
    if File.file?(location)
      return File.open(location, 'r')
    else
      raise "Invalid location: you need to supply either a URI or a file path to a word list."
    end
  end

  def ask_shell_for_encoding

  end

  def ensure_not_binary

  end

  def determine_encoding

  end

  def normalize_encoding

  end

end




# run
shell  = TTY::Prompt.new
@default_prompt = '>: ' # the *prompt* is the text displayed to prompt you to type, NOT the receiver of input.


puts @in_color.white.on_black 'You will need to find a word list or spelling dictionary as your starting point.'
puts 'Please enter the URI or file path to your word list:'
location = shell.ask(@default_prompt, default: "Portuguese.dic")
@word_list_file = App.get_word_list(location)

def line
  puts @in_color.blue "------------------------------------"
end

@possible_encodings = ['ASCII-8BIT', 'UTF-8', 'ISO-8859-1', 'ISO-8859-2', 'ISO-8859-15']
@encoding_hint = ''
line
#puts "DÃ©veloppement".encode("iso-8859-1").force_encoding("utf-8")

# ensure that it's not binary
command = TTY::Command.new
result = command.run('file', '--brief', '--keep-going', location)
if result.failure?
  puts in_color.red.on_black "Your system returned an error.  You may lack /usr/bin/file."
  # just keep going without using /usr/bin/file
else
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

sampler = EncodingSampler::Sampler.new(location, @sorted_encodings) # EncodingSampler changes @sorted_encodings! 😱
puts @in_color.green.on_black "Please choose correct encodings of the file."
choices = {}
@sorted_encodings.each do |encoding|
  choices["#{encoding}: #{sampler.sample(encoding).inspect}"] = encoding
end
choice = shell.select("Choose the first text sample that looks correct.", choices)
