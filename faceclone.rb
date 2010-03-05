require 'rubygems'
gem 'rest-client', '=1.0.3'
%w(config haml sinatra digest/md5 rack-flash json restclient models mini_fb).each  { |lib| require lib}
set :sessions, true
set :show_exceptions, false
use Rack::Flash

get "/" do
  if session[:userid].nil? then 
    haml :login 
  else
    @fb_uid = request.cookies[FB_API_KEY + "_user"]
    @fb_session = request.cookies[FB_API_KEY + "_session_key"]
    @all = @user.feed
    haml :landing
  end
end

get "/logout" do
  session[:userid] = nil
  redirect "/"
end

# called by RPX after the login completes
post "/after_login" do
  profile = get_user_profile_with params[:token]
  user = User.find(profile["identifier"])
  if user.new_record?
    photo = profile ["email"] ? "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(profile["email"])}" : profile["photo"] 
    unless user.update_attributes({:nickname => profile["identifier"].hash.to_s(36), :email => profile["email"], :photo_url => photo, :provider => profile["provider"]})
      flash[:error] = user.errors.values.join(",")
      redirect "/"
    end
    session[:userid] = user.id
    redirect "/user/profile/change"
  else
    session[:userid] = user.id
    redirect "/"    
  end
end

%w(user friends photos messages events).each {|feature| load "#{feature}.rb"}

before do
  @token = "http://#{env["HTTP_HOST"]}/after_login"
  @user = User.get(session[:userid]) if session[:userid]
end

load "helpers.rb"
