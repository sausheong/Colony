get "/user/profile" do
  puts @user.inspect
  haml :profile
end

get "/user/profile/change" do  
  haml :change_profile 
end

post "/user/profile" do
  unless @user.update_attributes(:nickname => params[:nickname], 
                                :formatted_name => params[:formatted_name], 
                                :location => params[:location], 
                                :description => params[:description], 
                                :sex => params[:sex], 
                                :relationship_status => params[:relationship_status], 
                                :interests => params[:interests], 
                                :education => params[:education])
    flash[:error] = @user.errors.values.join(",")
    redirect "/user/profile/change"
  end
  redirect "/"
end

post '/user/status' do
  Status.create(:text => params[:status], :user => @user)
  redirect "/"
end

post '/user/wall' do
  Post.create(:text => params[:status], :user => @user, :wall_id => params[:wallid])
  redirect "/user/#{params[:nickname]}"
end

get "/user/:nickname" do
  @myself = @user
  @viewed_user = User.first(:nickname => params[:nickname])
  @viewing_self = (@viewed_user == @myself)
  @all = [] + @viewed_user.activities + @viewed_user.wall.posts
  haml :user
end