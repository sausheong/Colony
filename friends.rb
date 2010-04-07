get '/friends' do
  if params[:query]
    results = User.all(:nickname.like => params[:query] + '%') + User.all(:formatted_name.like => '%' + params[:query] + '%')
    @search_results = results.uniq[0..24]
  end  
  haml :'/friends/friends', :locals => {:show_search => true, :user => @user}
end

get '/friends/:id' do
  viewed_user = User.get params[:id]
  haml :'/friends/friends', :locals => {:show_search => false, :user => viewed_user}
end

get '/request/:userid' do
  @friend = User.get(params[:userid])
  haml :'/friends/request'
end

put '/request' do
  Request.create(:text => params[:text], :from => @user, :user => User.get(params[:receiverid]))
  redirect '/friends'
end

get '/invite' do
  haml :'/friends/invite'
end

get '/requests/pending' do
  haml :'/friends/pending_requests'
end

put '/friend/:requestid' do
  req = Request.get(params[:requestid])
  req.approve
  req.destroy
  redirect '/requests/pending'
end
