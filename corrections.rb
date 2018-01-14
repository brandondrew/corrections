require 'tty'

# I'm going to go with Avdi's philosophy of OO, and not turn everything into Service Objects.
# I'm also going to use minitest for simplicity (& to try something new, as I normally use Rspec).
# I'm *also* going to embed test code & comments in my initial sketches, and reorganize later.
require "minitest/autorun"

in_color = Pastel.new

# methods:
#   determine_location_type(location)
#   fetch_word_list(location)
#   read_word_list(path)

# possible objects:
#   extractor
#   transformer
#   loader
#   corrector: one single object for everything...
#   producer:  what's the logical name for a single class?
#   app? short and sweet

# steps:
# 1 get the list based on user input
# 2 normalize the file encoding
# 3 ensure it has a usable format
# 4

# TEST: fetch_word_list can distinguish between a file path and a URI
# => gets a 200 when it

puts "before"
def fetch_word_list(location)
  # see https://mathiasbynens.be/demo/url-regex for alternatives
  web_uri_with_explicit_protocol = %r{https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)}
  web_uri_pattern = %r{(?i)\b((?:https?:(?:/{1,3}|[a-z0-9%])|[a-z0-9.\-]+[.](?:com|net|org|edu|gov|mil|aero|asia|biz|cat|coop|info|int|jobs|mobi|museum|name|post|pro|tel|travel|xxx|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cs|cu|cv|cx|cy|cz|dd|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|Ja|sk|sl|sm|sn|so|sr|ss|st|su|sv|sx|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw)/)(?:[^\s()<>{}\[\]]+|\([^\s()]*?\([^\s()]+\)[^\s()]*?\)|\([^\s]+?\))+(?:\([^\s()]*?\([^\s()]+\)[^\s()]*?\)|\([^\s]+?\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’])|(?:(?<!@)[a-z0-9]+(?:[.\-][a-z0-9]+)*[.](?:com|net|org|edu|gov|mil|aero|asia|biz|cat|coop|info|int|jobs|mobi|museum|name|post|pro|tel|travel|xxx|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cs|cu|cv|cx|cy|cz|dd|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|Ja|sk|sl|sm|sn|so|sr|ss|st|su|sv|sx|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw)\b/?(?!@)))}
  # TODO: simplify for practicality & permissiveness: our goal isn't validation, but to distinguish from file paths
  # web_uri_pattern = %r{(([a-z]{3,6}://)|(^|\s))([a-zA-Z0-9\-]+\.)+[a-z]{2,13}[\.\?\=\&\%\/\w\-]*\b([^@]|$)} # alternate to gruber's
#  file_path_pattern = %r{}
  case
  when location =~ web_uri_with_explicit_protocol || location =~ web_uri_pattern
    puts "That looks like a URI.  Well done."


  when File.file?(location)
    puts "That looks like a valid file.  Well done."
    return File.open(location, 'r')
  else
    raise "Invalid location: you need to supply either a URI or a file path to a word list."
  end
  return "SOME TEXT "
end


#file.each_line { |line|
#  puts line
#}
#file.close



shell  = TTY::Prompt.new
prompt = '>: ' # the *prompt* is the text displayed to prompt you to type, NOT the receiver of input.

puts 'You will need to find a word list or spelling dictionary as your starting point.'
puts 'Please enter the URI or file path to your word list:'
location = shell.ask(prompt, default: "Portuguese.dic")
@word_list_file = fetch_word_list(location)



# run a checksum, in case the user cares:
if shell.yes?('Do you want to compare checksum of the downloaded file to an expected value?')
  checksum_algorithm = shell.select("Which type of checksum do you need?", %w(sha sha1 sha224 sha256 sha384 sha512 md2 md4 md5))
  puts checksum_algorithm.inspect
  actual_checksum = TTY::File.checksum_file(@word_list_file, checksum_algorithm)
  actual_checksum = TTY::File.checksum_file("SOME TEXT HERE", checksum_algorithm)
  puts "The checksum of the downloaded file is: " + actual_checksum
  if shell.yes?('Do you want to paste your expected value, to ensure they are the same?')
    expected_checksum = shell.ask(prompt, default: "").chomp # TODO: check whether chomp is needed
    case
    when expected_checksum == actual_checksum
      puts in_color.green.on_black "The checksum is correct."
    else
      puts "hi"
    end
  end
end

