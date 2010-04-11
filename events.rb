# pages

put '/event/page' do
  event = Event.get params[:eventid]
  p = Page.create(:title => params[:title], :body => params[:body], :user => @user, :event => event)
  redirect "/event/page/#{p.id}"
end

delete '/event/page/:id' do
  Page.get(params[:id]).destroy
  redirect "/event/pages"
end

get '/event/:eventid/page/add' do
  @page = Page.new
  @event = Event.get params[:eventid]
  haml :'/pages/add', {:locals => {:owner => 'event'}}
end

get '/event/page/edit/:id' do
  @page = Page.get params[:id]
  haml :'/pages/add', {:locals => {:owner => 'event'}}  
end

post '/event/page' do
  p = Page.get params[:id]
  p.update_attributes(:title => params[:title], :body => params[:body])
  redirect "/event/page/#{p.id}"
end

get '/event/page/:id' do
  @page = Page.get params[:id]
  haml :'/pages/page', {:locals => {:owner => 'event'}}
end

# events

get '/events' do
  haml :'/events/manage'
end

get '/event/add' do
  haml :'/events/add'
end

put '/event' do
  e = Event.create(:name => params[:name], :description => params[:description], :venue => params[:venue], :date => params[:date], :time => params[:date] + " " + params[:time], :user => @user)
  if params[:invites]
    usrs = params[:invites].split(',')
    usrs.each do |u|
      invitee = User.first(:nickname => u.strip)
      Pending.create(:pending_event => e, :pending_user => invitee)
    end
    Confirm.create(:confirmed_event => e, :confirmed_user => @user)    
  end
  redirect "/event/#{e.id}"
end

delete '/event/:id' do
  e = Event.get params[:id]
  e.destroy
  redirect '/events'
end

get '/event/:id' do
  @event = Event.get params[:id]
  haml :'/events/event'
end

post '/event/wall' do
  Post.create(:text => params[:status], :user => @user, :wall_id => params[:wallid])
  redirect "/event/#{params[:event]}"  
end

post '/event/:id' do
  event = Event.get params[:id]  
  case params[:attendance]
  when 'yes'
    Pending.first(:user_id => @user.id, :event_id => event.id).destroy if event.pending_users.include? @user
    Decline.first(:user_id => @user.id, :event_id => event.id).destroy if event.declined_users.include? @user
    Confirm.create(:confirmed_event => event, :confirmed_user => @user)
  when 'no'

    Confirm.first(:user_id => @user.id, :event_id => event.id).destroy if event.confirmed_users.include? @user
    Pending.first(:user_id => @user.id, :event_id => event.id).destroy if event.pending_users.include? @user
    Decline.create(:declined_user => @user, :declined_event => event) 
  when 'maybe'
    Confirm.first(:user_id => @user.id, :event_id => event.id).destroy if event.confirmed_users.include? @user
    Decline.first(:user_id => @user.id, :event_id => event.id).destroy if event.declined_users.include? @user
    Pending.create(:pending_user => @user, :pending_event => event) 
  end
    
  redirect "/event/#{event.id}"  
end

