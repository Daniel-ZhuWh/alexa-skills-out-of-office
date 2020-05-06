require "sinatra"
# require 'sinatra/reloader' if development?

require 'alexa_skills_ruby'
require 'httparty'
require 'iso8601'
require 'twilio-ruby'
# require 'whenever'


# ----------------------------------------------------------------------

# Load environment variables using Dotenv. If a .env file exists, it will
# set environment variables from that file (useful for dev environments)
configure :development do
  require 'dotenv'
  Dotenv.load
end

# enable sessions for this project
enable :sessions

def determine_response body
	#customize response message according to user input

	#keyword lists
	greeting_kwd = ['hi', 'hello', 'hey']
	who_kwd = ['who']
	what_kwd = ['what', 'features', 'functions', 'actions', 'help']
	where_kwd = ['where']
	when_kwd = ['when', 'time']
	why_kwd = ['why']
	joke_kwd = ['joke']
	fact_kwd = ['fact']
	funny_kwd = ['lol', 'haha', 'hh']
  weather_kwd = ['weather']
  diet_kwd = ['track diet', 'track', 'log']

	body = body.downcase.strip
  if session[:last_msg] == 'default'
    if include_keywords body, greeting_kwd
  		return "Hi there, my app tells you a little about me.<br>"
  	elsif include_keywords body, who_kwd
  		return "It's MeBot created by Daniel here!<br>
  						If you want to know more about me, you can input 'fact' to the Body parameter."
  	elsif include_keywords body, what_kwd
  		return "You can ask anything you are interested about me.<br>"
  	elsif include_keywords body, where_kwd
  		return "I'm in Pittsburgh~<br>"
  	elsif include_keywords body, when_kwd
  		return "The bot is made in Spring 2020.<br>"
  	elsif include_keywords body, why_kwd
  		return "It was made for class project of 49714-pfop.<br>"
  	elsif include_keywords body, joke_kwd
  		array_of_lines = IO.readlines("jokes.txt")
  		return array_of_lines.sample
  	elsif include_keywords body, fact_kwd
  		array_of_lines = IO.readlines("facts.txt")
  		return array_of_lines.sample
  	elsif include_keywords body, funny_kwd
  		return "Nice one right lol."
    elsif include_keywords body, diet_kwd
      session[:last_msg] = 'log_meal'
      return "Sure, what food did you have?"
  	else
      message = "Sorry, your input cannot be understood by the bot.<br>
  						Try using two parameters called Body and From."
      return message
    end
  elsif session[:last_msg] == 'log_meal'
    return get_nutrients body
	end
end

def include_keywords body, keywords
	# check if string contains any word in the keywords array
	keywords.each do |keyword|
		puts "now checking" + keyword
		if body.downcase.include?(keyword)
			return true
		end
  end
	return false
end

def get_nutrients body
  url = 'https://trackapi.nutritionix.com/v2/natural/nutrients'
  res = HTTParty.post url, body: { query:body, timezone: "US/Eastern"}.to_json, headers: {'content-type' => 'application/json', 'x-app-id' => ENV['NUTRITIONIX_ID'], 'x-app-key' => ENV['NUTRITIONIX_KEY']}

  total_fat = 0
  total_protein = 0
  total_cal = 0
  res['foods'].each do |food|
    total_fat += food['nf_total_fat']
    total_protein += food['nf_protein']
    total_cal += food['nf_calories']
  end
  total_fat = total_fat.to_i
  total_protein = total_protein.to_i
  total_cal = total_cal.to_i

  msg = "You consumed approximately #{total_cal} calories in total with #{total_protein} grams of protein and #{total_fat} grams of fat."
  return msg
end

def send_sms message, to_number
	client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]
	# Include a message here

	# this will send a message from any end point
	client.api.account.messages.create(
		from: ENV["TWILIO_FROM"],
		to: to_number,
		body: message
	)
end


class CustomHandler < AlexaSkillsRuby::Handler

  on_launch() do
    response.set_output_speech_text("Hi there, I'm your diet bot.")
    logger.info 'Lauch request processed'
  end

  on_intent("REQUEST_TO_LOG_MEAL") do
    # add a response to Alexa
    response.set_output_speech_text("Sure, what food did you have?")
    # create a card response in the alexa app
    response.set_simple_card("Diet Bot App", "Meal logged. Have a nice day!")
    # log the output if needed
    logger.info 'REQUEST_TO_LOG_MEAL processed'
    response.should_end_session = false
    # send a message to slack
    # update_status "DO_NOT_DISTURB"
  end

  on_intent("LOG_MEAL") do
    food_log = request.intent.slots["food_log"]
    # add a response to Alexa
    res = get_nutrients food_log

    response.set_output_speech_text("#{res}")
    # create a card response in the alexa app
    response.set_simple_card("Diet Bot App", "#{res}")
    # log the output if needed
    logger.info "#{res}"
    # send a message to slack
    # update_status "DO_NOT_DISTURB"
  end

  on_intent("AMAZON.HelpIntent") do
    response.set_output_speech_ssml("<speak>You can ask me to log your meal status by saying
      <break time='200ms'/><emphasis level='moderate'>log meal</emphasis>.
      and then saying what food you had <break time='200ms'/>.
      For example, you can say
      <break time='150ms'/>I had an apple for breakfast,
      <break time='100ms'/>or
      <break time='100ms'/>I ate a hamburger just now.
      <break time='150ms'/>Calories and more data about the food will be responded to you.
      </speak>")
    logger.info 'HelpIntent processed'
  # end

  # on_intent("BACK_IN") do
  #
	# 	# Access the slots
  #   slots = request.intent.slots
  #   puts slots.to_s
  #
	# 	# Duration is returned in a particular format
	# 	# Called ISO8601. Translate this into seconds
  #   duration = ISO8601::Duration.new( request.intent.slots["duration"] ).to_seconds
  #
	# 	# This will downsample the duration from a default seconds
	# 	# To...
  #   if duration > 60 * 60 * 24
  #     days = duration/(60 * 60 * 24).round
  #     response.set_output_speech_text("I've set you away for #{ days } days")
  #   elsif duration > 60 * 60
  #     hours = duration/(60 * 60 ).round
  #     response.set_output_speech_text("I've set you away for #{ hours } hours")
  #   else
  #     mins = duration/(60).round
  #     response.set_output_speech_text("I've set you away for #{ mins } minutes")
  #   end
  #   logger.info 'BackIn processed'
  #   update_status "BACK_IN", duration
  # end
  #
  # on_intent("TEST") do
  #   response.set_output_speech_ssml("<speak>
  #   Welcome to Car-Fu.
  #   <audio src='soundbank://soundlibrary/transportation/amzn_sfx_car_accelerate_01' />
  #   You can order a ride, or request a fare estimate.
  #   Which will it be?
  #   </speak>")
  #
  #   logger.info 'TEST processed'
  # end
end

# ----------------------------------------------------------------------
#     ROUTES, END POINTS AND ACTIONS
# ----------------------------------------------------------------------


get '/' do
  404
end

# while true do
#   puts "3 seconds"
#   sleep 3
# end
# THE APPLICATION ID CAN BE FOUND IN THE
get '/test/scheduler' do
  while true do
    puts "3 seconds"
    sleep 3
  end
end

get "/sms/incoming" do
  session[:last_msg] = 'default'
  body = params[:Body] || ""
  sender = params[:From] || ""
  message = determine_response body
  send_sms message, sender

  media = 'https://www.metmuseum.org/-/media/images/visit/met-fifth-avenue/fifthave_teaser.jpg'
  twiml = Twilio::TwiML::MessagingResponse.new do |r|
    r.message do |m|

      # add the text of the response
      m.body( message )

      # add media if it is defined
      unless media.nil?
        m.media( media )
			end
    end
  end

  # increment the session counter
  # session["counter"] += 1

  # send a response to twilio
  content_type 'text/xml'
  twiml.to_s
end


post '/incoming/alexa' do
  content_type :json

  handler = CustomHandler.new(application_id: ENV['ALEXA_APPLICATION_ID'], logger: logger)

  begin
    hdrs = { 'Signature' => request.env['HTTP_SIGNATURE'], 'SignatureCertChainUrl' => request.env['HTTP_SIGNATURECERTCHAINURL'] }
    handler.handle(request.body.read, hdrs)
  rescue AlexaSkillsRuby::Error => e
    logger.error e.to_s
    403
  end

end



# ----------------------------------------------------------------------
#     ERRORS
# ----------------------------------------------------------------------



error 401 do
  "Not allowed!!!"
end

# ----------------------------------------------------------------------
#   METHODS
#   Add any custom methods below
# ----------------------------------------------------------------------

private
