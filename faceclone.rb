gem 'rest-client', '=1.0.3'
%w(rubygems config haml sinatra digest/md5 rack-flash json restclient models mini_fb).each  { |lib| require lib}
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
    redirect "/change_profile"
  else
    session[:userid] = user.id
    redirect "/"    
  end
end



get "/profile" do
  puts @user.inspect
  haml :profile
end

get "/change_profile" do  
  haml :change_profile 
end

post "/save_profile" do
  unless @user.update_attributes(:nickname => params[:nickname], 
                                :formatted_name => params[:formatted_name], 
                                :location => params[:location], 
                                :description => params[:description], 
                                :sex => params[:sex], 
                                :relationship_status => params[:relationship_status], 
                                :interests => params[:interests], 
                                :education => params[:education])
    flash[:error] = @user.errors.values.join(",")
    redirect "/change_profile"
  end
  redirect "/"
end

post '/update' do
  Status.create(:text => params[:status], :user => @user)
  redirect "/"
end

post '/update_wall' do
  Post.create(:text => params[:status], :user => @user, :wall_id => params[:wallid])
  redirect "/#{params[:nickname]}"
end


get '/friends' do
  if params[:query]
    results = User.all(:nickname.like => params[:query] + '%') + User.all(:formatted_name.like => '%' + params[:query] + '%')
    @search_results = results.uniq[0..24]
  end  
  haml :friends
end

get '/request/:userid' do
  @friend = User.get(params[:userid])
  haml :request
end

put '/request' do
  Request.create(:text => params[:text], :from => @user, :user => User.get(params[:receiverid]))
  redirect '/friends'
end


get '/follow/:nickname' do
  Relationship.create(:user => User.first(:nickname => params[:nickname]), :follower => User.get(session[:userid]))
  redirect "/#{params[:nickname]}"
end

delete '/follow/:user_id/:follows_id' do
  Relationship.first(:follower_id => params[:user_id], :user_id => params[:follows_id]).destroy
  redirect "/"
end

get '/messages/:dir' do
  load_users(session[:userid])
  @friends = @myself.follows & @myself.followers
  case params[:dir]
  when 'received' then @messages = Status.all(:recipient_id => @myself.id); @label = "Direct messages sent only to you"
  when 'sent'     then @messages = Status.all(:user_id => @myself.id, :recipient_id.not => nil); @label = "Direct messages you've sent"
  end
  @message_count = message_count 
  haml :messages
end

post '/message/send' do
  recipient = User.first(:nickname => params[:recipient])
  Status.create(:text => params[:message], :user => User.get(session[:userid]), :recipient => recipient)
  redirect '/messages/sent'
end

get '/invite' do
  haml :invite
end

get '/requests/pending' do
  haml :pending_requests
end

put '/friend/:requestid' do
  req = Request.get(params[:requestid])
  req.user.add_friend(req.from)
  req.destroy
  redirect '/requests/pending'
end

load "photos.rb"

get "/:nickname" do
  @myself = @user
  @viewed_user = User.first(:nickname => params[:nickname])
  @viewing_self = (@viewed_user == @myself)
  @all = [] + @viewed_user.activities + @viewed_user.wall.posts
  haml :user
end


before do
  @token = "http://#{env["HTTP_HOST"]}/after_login"
  @user = User.get(session[:userid]) if session[:userid]
end

load "helpers.rb"
