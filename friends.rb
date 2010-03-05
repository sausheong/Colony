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
