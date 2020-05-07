require "sinatra"
# require 'sinatra/reloader' if development?

require 'alexa_skills_ruby'
require 'httparty'
require 'iso8601'
require 'twilio-ruby'
require 'json'
# require 'whenever'

$current_sender = ''
# ----------------------------------------------------------------------

# Load environment variables using Dotenv. If a .env file exists, it will
# set environment variables from that file (useful for dev environments)
configure :development do
  require 'dotenv'
  Dotenv.load
end

# enable sessions for this project
enable :sessions

def update_log cal, pro, fat
  obj = JSON.parse(IO.read('food_log.json'))
  obj['cal_sum'] += cal
  obj['pro_sum'] += pro
  obj['fat_sum'] += fat
  File.open("food_log.json","w") do |f|
    f.write(obj.to_json)
  end
end

def tutorial_update_log mealtype, cal
  obj = JSON.parse(IO.read('food_log.json'))
  temp = mealtype + "_cal"
  obj[temp] += cal
  obj['cal_sum'] += cal
  File.open("food_log.json","w") do |f|
    f.write(obj.to_json)
  end
end

def initialize_log
  hash = {
    # "foods" => [],
    "breakfast_cal" => 0,
    "lunch_cal" => 0,
    "dinner_cal" => 0,
    "cal_sum" => 0,
    "pro_sum" => 0,
    "fat_sum" => 0,
    "cal_limit" => 2000
  }
  File.open("food_log.json","w") do |f|
    f.write(hash.to_json)
  end
end

def get_summary
  motivate_quotes = ['The struggle you are in today is developing the strength you need for tomorrow🙂',
  'The road may be bumpy but stay committed to the process🙂',
  'If you are tired of starting over, stop giving up🙂',
  'It’s not a diet, it’s a lifestyle change🙂',
  'Will is a skill🙂',
  'Stressed spelled backwards is desserts. coincidence? I think not!🙃',
  'Strive for progress, not perfection💪',
  'Success is never certain, failure is never final🙂',
  'A goal without a plan is just a wish🙂']

  obj = JSON.parse(IO.read('food_log.json'))
  cal_sum = obj['cal_sum'].to_f
  cal_limit = obj['cal_limit'].to_f
  dif = (cal_limit - cal_sum)/cal_limit

  if dif < -0.25
    message = "You've exceeded your daily calorie limit a lot! \n"+ motivate_quotes.sample + "\nDon't worry, I'm here for you"
  elsif dif < 0
    message = "You've run out of your calorie limit for the day. Don't forget your plans~"
  elsif dif < 0.15
    message = "You have less than 300 calories left for your daily limit. That's about the amount of a light breakfast.🥪"
  elsif dif < 0.25
    message = "You have less than 500 calories left for your daily limit. That's about a hamburger, but I'm not suggesting you to eat that!😂"
  else
    message = "You have more than 500 calories left for your daily limit. That's more than a proper meal. Go ahead and enjoy the food!😀"
  end
  return message
end

def determine_response body
	#customize response message according to user input
  # puts session[:last_msg]
	#keyword lists
	greeting_kwd = ['hi', 'hello', 'hey']
	who_kwd = ['who']
	what_kwd = ['what', 'features', 'functions', 'actions', 'help']
	where_kwd = ['where']
	when_kwd = ['when', 'time']
	why_kwd = ['why']
	# joke_kwd = ['joke']

	fact_kwd = ['fact']
	funny_kwd = ['lol', 'haha', 'hh', 'cool']
  # weather_kwd = ['weather']
  diet_kwd = ['track diet', 'track', 'log']
  summary_kwd = ['summary', 'summarize']
  tutorial_kwd = ['tutorial']

	body = body.downcase.strip

  if include_keywords body, tutorial_kwd
    message = "Sure. I'm a Diet Bot that can help you log the calories of your meals🤖.\nWould you like to tell me what you had for breakfast?"
    session[:mode] = 'tutorial'
    initialize_log
    session[:tutorial_intent] = 'ask_for_breakfast'
  elsif session[:tutorial_intent] == 'ask_for_breakfast' && session[:mode] == 'tutorial'
    results = get_nutrients body
    cal = results[1].to_f
    tutorial_update_log "breakfast", cal
    session[:tutorial_intent] = 'ask_for_lunch'
    message1 = "You had about #{cal} calories for breakfast."
    message2 = get_summary
    send_sms message1, $current_sender
    sleep(2)
    send_sms message2, $current_sender
    sleep(2)
    message = "Would you like to tell me about your lunch then?"
  elsif session[:tutorial_intent] == 'ask_for_lunch' && session[:mode] == 'tutorial'
    results = get_nutrients body
    cal = results[1].to_f
    tutorial_update_log "lunch", cal
    session[:tutorial_intent] = 'ask_for_dinner'
    message1 = "You had about #{cal} calories for lunch."
    message2 = get_summary
    send_sms message1, $current_sender
    sleep(2)
    send_sms message2, $current_sender
    sleep(2)
    message = "Would you like to tell me about your dinner then?\nYou can try to say something like '8 hamburgers' to exceed the daily calorie limit and see what will happen😇."
  elsif session[:tutorial_intent] == 'ask_for_dinner' && session[:mode] == 'tutorial'
    results = get_nutrients body
    cal = results[1].to_f
    tutorial_update_log "dinner", cal
    session[:tutorial_intent] = 'send_summary'
    message1 = "You had about #{cal} calories for dinner."
    message2 = get_summary
    send_sms message1, $current_sender
    sleep(2)
    send_sms message2, $current_sender
    sleep(2)
    message = "Do you want to see a summary of your today's meal info?"

  elsif session[:tutorial_intent] == 'send_summary' && session[:mode] == 'tutorial'
    # results = get_nutrients body
    # cal = results[1]
    # tutorial_update_log "dinner", cal
    obj = JSON.parse(IO.read('food_log.json'))
    b_cal = obj['breakfast_cal']
    l_cal = obj['lunch_cal']
    d_cal = obj['dinner_cal']

    initialize_log

    session[:tutorial_intent] = ''
    session[:mode] = ''
    message = "【breakfast】#{b_cal} calories\n【lunch】#{l_cal} calories\n【dinner】#{d_cal} calories\nThat's the end of the tutorial!👍\nIn the future, you can text me 'Track' or 'Log' to log your meal info.\nOr you can just say to alexa 'Tell diet bot to log meal'😘\nVery handy, right?"
  elsif session[:last_msg] == 'default'
    puts "default"
    if include_keywords body, greeting_kwd
  		message = "Hi there, it's Diet Bot🤖."
  	elsif include_keywords body, who_kwd
  		message = "It's Diet Bot created by Daniel here!\nIf you want to know more about me, you can say 'fact'."
  	elsif include_keywords body, what_kwd
  		message = "I help you log your meals💪.\nLog meal by saying 'Track meal'.\nIf you are new to me, no worries👌. Start tutorial by saying 'tutorial'."
  	elsif include_keywords body, where_kwd
  		message = "I'm in Pittsburgh~<br>"
  	elsif include_keywords body, when_kwd
  		message = "The bot is made in Spring 2020.<br>"
  	elsif include_keywords body, why_kwd
  		message = "It was made for class project of 49714-pfop.<br>"
  	# elsif include_keywords body, joke_kwd
  	# 	array_of_lines = IO.readlines("jokes.txt")
  	# 	message = array_of_lines.sample
  	elsif include_keywords body, fact_kwd
  		array_of_lines = IO.readlines("facts.txt")
  		message = array_of_lines.sample
  	elsif include_keywords body, funny_kwd
  		message = "😁"
    elsif include_keywords body, summary_kwd
      message = get_summary
    elsif include_keywords body, diet_kwd
      session[:last_msg] = 'log_meal'
      message = "Sure, what food did you have?"
  	else
      message = "Sorry, your input cannot be understood by the bot.<br>"
    end

  # meal logging
  elsif session[:last_msg] == 'log_meal' || session[:last_msg] == 'further_log_meal'
    results = get_nutrients body
    temp = results[0]
    update_log results[1].to_i, results[2].to_i, results[3].to_i
    send_sms temp, $current_sender
    if session[:last_msg] != 'further_log_meal'
      session[:last_msg] = 'default'
    end
    message = get_summary
	end
  puts "modified" + session[:last_msg]
  message
  return message
end

def include_keywords body, keywords
	# check if string contains any word in the keywords array
	keywords.each do |keyword|
		# puts "now checking" + keyword
		if body.downcase.include?(keyword)
			return true
		end
  end
	return false
end

def get_nutrients body
  url = 'https://trackapi.nutritionix.com/v2/natural/nutrients'
  puts body
  res = HTTParty.post url, body: { query:body, timezone: "US/Eastern"}.to_json, headers: {'content-type' => 'application/json', 'x-app-id' => ENV['NUTRITIONIX_ID'], 'x-app-key' => ENV['NUTRITIONIX_KEY']}

  total_fat = 0
  total_protein = 0
  total_cal = 0
  if res['foods'].nil?
    msg = "I can't seem to recognize any food in what you said. Can you be more specific please?"
    session[:last_msg] = "further_log_meal"
    return msg
  else
    res['foods'].each do |food|
      total_fat += food['nf_total_fat']
      total_protein += food['nf_protein']
      total_cal += food['nf_calories']
    end
    #save changes to json file
    # update_log total_cal, total_protein, total_fat

    total_fat = total_fat.to_i
    total_protein = total_protein.to_i
    total_cal = total_cal.to_i

    msg = "You consumed approximately #{total_cal} calories."
    return msg, total_cal, total_protein, total_fat
  end
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
    response.set_simple_card("Welcome!", "It's Diet Bot here.")
    response.should_end_session = false
  end

  on_intent("REQUEST_TO_LOG_MEAL") do
    # add a response to Alexa
    response.set_output_speech_text("Sure, what food did you have?")
    # create a card response in the alexa app
    response.set_simple_card("Logging meal", "You can tell me what you ate by saying 'I had...' or 'I ate...'")
    # log the output if needed
    logger.info 'REQUEST_TO_LOG_MEAL processed'
    response.should_end_session = false
    # send a message to slack
    # update_status "DO_NOT_DISTURB"
  end

  on_intent("LOG_MEAL") do
    food_log = request.intent.slots["food_log"]
    # add a response to Alexa
    results = get_nutrients food_log
    res = results[0]
    update_log results[1].to_i, results[2].to_i, results[3].to_i
    summary = get_summary
    response.set_output_speech_text("#{res} #{summary}")
    # create a card response in the alexa app
    response.set_simple_card("Meal logged", "#{res}\nCalories: #{results[1]}g\nProtein: #{results[2]}g\nFat: #{results[3]}g")
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
    response.set_simple_card("Help info", "You can ask me to log your meal status by saying
      LOG MEAL
      and then saying what food you had.For example, you can say
      I HAD AN APPLE FOR BREAKFAST
      or
      I ATE A HAMBURGER JUST NOW
      Calories and more data about the food will be responded to you.")
    logger.info 'HelpIntent processed'
    response.should_end_session = false
  end

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
# get '/test/scheduler' do
#   while true do
#     puts "3 seconds"
#     sleep 3
#   end
# end

get "/sms/incoming" do
  # sms intercation through twilio
  if session[:last_msg] != 'log_meal' && session[:last_msg] != 'further_log_meal'
    session[:last_msg] = 'default'
  end
  body = params[:Body] || ""
  sender = params[:From] || ""
  $current_sender = sender
  message = determine_response body
  send_sms message, sender
  message
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

get "/test/food" do
  url = 'https://trackapi.nutritionix.com/v2/natural/nutrients'

  res = HTTParty.post url, body: { query:"I ate two eggs and one ham.", timezone: "US/Eastern"}.to_json, headers: {'content-type' => 'application/json', 'x-app-id' => 'fdeb15cb', 'x-app-key' => '
  8521704bdf8b2eadfa20a6bd17b043e5'}

  puts res.class
  # puts res.to_json.class
  # obj = JSON.parse(res.body)
  # puts obj.class
  total_fat = 0
  total_protein = 0
  total_cal = 0
  # fat = res['foods'][0]['nf_total_fat'].to_s
  res['foods'].each do |food|
    total_fat += food['nf_total_fat']
    total_protein += food['nf_protein']
    total_cal += food['nf_calories']
  end
  # "You consumed #{total_cal} calories in total with #{total_protein} grams of protein and #{total_fat} grams of fat."
end

# ----------------------------------------------------------------------
#     ERRORS
# ----------------------------------------------------------------------
get "/ini" do
  hash = {
    # "foods" => [],
    "breakfast_cal" => 0,
    "lunch_cal" => 0,
    "dinner_cal" => 0,
    "cal_sum" => 0,
    "pro_sum" => 0,
    "fat_sum" => 0,
    "cal_limit" => 2000
  }
  File.open("food_log.json","w") do |f|
    f.write(hash.to_json)
  end
end

get "/clr" do
  obj = JSON.parse(IO.read('food_log.json'))
  # obj['foods'] = []
  obj['cal_sum'] = 0
  obj['pro_sum'] = 0
  obj['fat_sum'] = 0

  File.open("food_log.json","w") do |f|
    f.write(obj.to_json)
  end
end

get "/summary" do
  get_summary
end

error 401 do
  "Not allowed!!!"
end

# ----------------------------------------------------------------------
#   METHODS
#   Add any custom methods below
# ----------------------------------------------------------------------
