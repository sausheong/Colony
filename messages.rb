get '/messages/:type' do
  @friends = @user.friends
  case params[:type]
  when 'inbox'   then @messages = Message.all(:recipient_id => @user.id); @label = 'Inbox'
  when 'sent_box' then @messages = Message.all(:user_id => @user.id); @label = 'Sent'
  end

  haml :messages
end

post '/message/send' do
  recipient = User.first(:nickname => params[:recipient])
  Message.create(:subject => params[:subject], :text => params[:text], :sender => @user, :recipient => recipient)
  redirect '/messages/sent_box'
end

get '/message/:id' do
  @message = Message.get(params[:id])
  haml :message
end