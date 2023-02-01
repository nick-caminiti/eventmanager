require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s.gsub(/[^\d]/, '')
  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number[1..9]
  else
    'Bad phone number'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def convert_to_datetime(regdate)
  DateTime.strptime(regdate,"%m/%d/%y %H:%M")
end

def find_reg_hour(regdate)
  regdate_time = convert_to_datetime(regdate)
  regdate_time.strftime("%k")
end

def find_dow(regdate)
  regdate_time = convert_to_datetime(regdate)
  regdate_time.wday
end


puts 'EventManager Initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hour_array = []
dow_array = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone_number = clean_phone_number(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  hour_array << find_reg_hour(row[:regdate])
  dow_array << find_dow(row[:regdate])

  # puts "#{name} #{row[:regdate]} #{reg_hour}"
end

dow_dictionary = {
  '0' => 'Sunday',
  '1' => 'Monday',
  '2' => 'Tuesday',
  '3' => 'Wednesday',
  '4' => 'Thursday',
  '5' => 'Friday',
  '6' => 'Saturday'
}

dow_array = dow_array.map{|value| value.to_s.gsub(/[0-6]/, dow_dictionary)}

hour_hash = hour_array.reduce(Hash.new(0)) do |hour_hash, hour|
  hour_hash[hour] +=1
  hour_hash
end

dow_hash = dow_array.reduce(Hash.new(0)) do |dow_hash, dow|
  dow_hash[dow] +=1
  dow_hash
end

def largest_key(hash)
  hash.max_by{|k, v| v}[0]
end

hour_hash.sort_by {|_key, value| value}.reverse.to_h
dow_hash.sort_by {|_key, value| value}.reverse.to_h

puts "Most active hour is #{largest_key(hour_hash)}"
puts "Most active day is #{largest_key(dow_hash)}"