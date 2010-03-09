get '/pages' do
  haml :'/pages/manage'
end





put '/page' do
  p = Page.create(:title => params[:title], :body => params[:body], :user => @user)
  redirect "/page/#{p.id}"
end


delete '/page/:id' do
  Page.get(params[:id]).destroy
  redirect "/pages"
end

get '/page/add' do
  @page = Page.new
  haml :'/pages/add'
end


get '/page/edit/:id' do
  @page = Page.get params[:id]
  haml :'/pages/add'  
end


post '/page' do
  p = Page.get params[:id]
  p.update_attributes(:title => params[:title], :body => params[:body])
  redirect "/page/#{p.id}"
end

get '/page/:id' do
  @page = Page.get params[:id]
  haml :'/pages/page'
end
