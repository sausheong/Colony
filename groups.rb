# pages

put '/group/page' do
  group = Group.get params[:groupid]
  p = Page.create(:title => params[:title], :body => params[:body], :user => @user, :group => group)
  redirect "/group/page/#{p.id}"
end

delete '/group/page/:id' do
  Page.get(params[:id]).destroy
  redirect "/group/pages"
end

get '/group/:groupid/page/add' do
  @page = Page.new
  @group = Group.get params[:groupid]
  haml :'/pages/add', {:locals => {:owner => 'group'}}
end

get '/group/page/edit/:id' do
  @page = Page.get params[:id]
  haml :'/pages/add', {:locals => {:owner => 'group'}}  
end

post '/group/page' do
  p = Page.get params[:id]
  p.update_attributes(:title => params[:title], :body => params[:body])
  redirect "/group/page/#{p.id}"
end

get '/group/page/:id' do
  @page = Page.get params[:id]
  haml :'/pages/page', {:locals => {:owner => 'group'}}
end

# groups

get '/groups' do
  haml :'/groups/manage'
end

get '/group/add' do
  haml :'/groups/add'
end

post '/group/join/:id' do
  group = Group.get params[:id]
  group.members << @user
  group.save
  redirect "/group/#{params[:id]}"
end

post '/group/leave/:id' do
  group = Group.get params[:id]
  if group.members.include?(@user)
    group.members.delete(@user)    
    group.save
  end
  redirect "/group/#{params[:id]}"  
end


put '/group' do
  g = Group.create(:name => params[:name], :description => params[:description],  :user => @user)
  g.members << @user
  g.save
  redirect "/group/#{g.id}"
end

delete '/group/:id' do
  g = Group.get params[:id]
  g.destroy
  redirect '/groups'
end

get '/group/:id' do
  @group = Group.get params[:id]
  haml :'/groups/group'
end

post '/group/wall' do
  Post.create(:text => params[:status], :user => @user, :wall_id => params[:wallid])
  redirect "/group/#{params[:group]}"  
end

post '/group/:id' do
  group = Group.get params[:id] 
  group.update_attributes(:name => params[:name], :description => params[:description] )   
  redirect "/group/#{group.id}"  
end

