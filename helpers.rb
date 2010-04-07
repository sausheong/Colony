helpers do

  def get_user_profile_with(token)
    response = RestClient.post 'https://rpxnow.com/api/v2/auth_info', 'token' => token, 'apiKey' => RPX_API_KEY, 'format' => 'json', 'extended' => 'true'
    json = JSON.parse(response)
    return json['profile'] if json['stat'] == 'ok'
    raise LoginFailedError, 'Cannot log in. Try another account!' 
  end


  def time_ago_in_words(timestamp)
    minutes = (((Time.now - timestamp).abs)/60).round
    return nil if minutes < 0

    case minutes
    when 0               then 'less than a minute ago'
    when 0..4            then 'less than 5 minutes ago'
    when 5..14           then 'less than 15 minutes ago'
    when 15..29          then 'less than 30 minutes ago'
    when 30..59          then 'more than 30 minutes ago'
    when 60..119         then 'more than 1 hour ago'
    when 120..239        then 'more than 2 hours ago'
    when 240..479        then 'more than 4 hours ago'
    else                 timestamp.strftime('%I:%M %p %d-%b-%Y')
    end
  end
 
  def snippet(page, options={})
    haml page, options.merge!(:layout => false)
  end
  
end