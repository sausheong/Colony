get '/messages/:type' do
  @friends = @user.friends
  case params[:type]
  when 'inbox'   then @messages = Message.all(:recipient_id => @user.id, :order => [ :created_at.desc ]); @label = 'Inbox'
  when 'sent_box' then @messages = Message.all(:user_id => @user.id, :order => [ :created_at.desc ]); @label = 'Sent'
  end

  haml :'/messages/messages'
end

post '/message/send' do
  recipient = User.first(:nickname => params[:recipient])
  m = Message.create(:subject => params[:subject], :text => params[:text], :sender => @user, :recipient => recipient)
  if params[:thread].nil?
    m.thread =  m.id
  else
    m.thread = params[:thread].to_i
  end 
  m.save    
  redirect '/messages/sent_box'
end

get '/message/:id' do
  @message = Message.get(params[:id])
  @message.read = true
  @message.save
  @messages = Message.all(:thread => @message.thread).sort{|m1, m2| m1.created_at <=> m2.created_at}
  haml :'/messages/message'
end

delete '/message/:id' do
  message = Message.get(params[:id])
  if message.sender == @user
    message.sender = nil
  elsif message.recipient == @user
    message.recipient = nil
  end
  message.save
  redirect '/messages/inbox'
end