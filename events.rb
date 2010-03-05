get '/events' do
  
  haml :'/events/manage'
end


get '/event/:id' do
  
  haml :'/events/event'
end

get '/event/add' do
  
  haml :'/event/add'
end

put '/event' do
  
  redirect "/event/#{event.id}"
end


