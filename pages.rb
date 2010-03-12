get '/user/pages' do
  haml :'/pages/manage', {:locals => {:owner => 'user'}}
end

put '/user/page' do
  p = Page.create(:title => params[:title], :body => params[:body], :user => @user)
  redirect "/user/page/#{p.id}"
end

delete '/user/page/:id' do
  Page.get(params[:id]).destroy
  redirect "/user/pages"
end

get '/user/page/add' do
  @page = Page.new
  haml :'/pages/add', {:locals => {:owner => 'user'}}
end

get '/user/page/edit/:id' do
  @page = Page.get params[:id]
  haml :'/pages/add', {:locals => {:owner => 'user'}}  
end

post '/user/page' do
  p = Page.get params[:id]
  p.update_attributes(:title => params[:title], :body => params[:body])
  redirect "/user/page/#{p.id}"
end

get '/user/page/:id' do
  @page = Page.get params[:id]
  haml :'/pages/page', {:locals => {:owner => 'user'}}
end