get "/albums" do
  @myself = @user = User.get(session[:userid])
  haml :"albums/manage"
end

get "/albums/:user_id" do
  @myself = User.get(session[:userid])
  @user = User.get(params[:user_id])
  haml :"albums/manage"
end


# add album
get "/album/add" do 
  @user = User.get(session[:userid])
  haml :"/albums/add"
end

# create album
post "/album/create" do
  album = Album.new
  album.attributes = {:name => params[:name], :description => params[:description]}
  album.user = User.get(session[:userid])
  album.save
  redirect "/albums"
end

post "/album/cover/:photo_id" do
   photo = Photo.get(params[:photo_id])  
   album = photo.album
   album.cover_photo = photo   
   album.save!
   redirect "/album/#{album.id}"
end

# delete album
delete "/album/:id" do
  album = Album.get(params[:id])
  user = User.get(session[:userid])
  if album.user == user
    if album.destroy
      redirect "/albums"
    else
      throw "Cannot delete this album!"
    end
  else
    throw "This is not your album, you cannot delete it!"
  end
end

# show all photos in this album
get "/album/:id" do
  @album = Album.get params[:id]
  @user = User.get session[:userid]
  haml :"/albums/view"
end

# save an edited photo
post "/photo/save_edited/:original_photo_id" do
  if params[:original_photo_id] && params["image"] && (tmpfile = params["image"][:tempfile]) && (name = params["image"][:filename])
    original_photo = Photo.get params[:original_photo_id]
    new_photo = Photo.new(:title => name, :album => original_photo.album, :tmpfile => tmpfile)
    original_photo.versions << new_photo
    original_photo.save    
  end  
  redirect "/photo/#{original_photo.id}"
end

# edit photo properties
post "/photo/:property/:photo_id" do
  photo = Photo.get params[:photo_id]
  photo.send(params[:property] + '=', params[:value])
  photo.save
  photo.send(params[:property])
end

# edit album properties
post "/album/:property/:photo_id" do
  album = Album.get params[:photo_id]
  album.send(params[:property] + '=', params[:value])
  album.save
  album.send(params[:property])
end


# show this photo
get "/photo/:id" do
  @photo = Photo.get params[:id]
  @user = User.get session[:userid]
  halt 403, 'This is a private photo' if @photo.privacy == 'Private' and @user != @photo.album.user
  
	notes = @photo.annotations.collect do |n|
    '{"x1": "' + n.x.to_s + '", "y1": "' + n.y.to_s + 
    '", "height": "' + n.height.to_s + '", "width": "' + n.width.to_s + 
    '","note": "' + n.description + '"}'
  end
  @notes = notes.join(',')
  @prev_in_album = @photo.previous_in_album
  @next_in_album = @photo.next_in_album
  haml :'/photos/photo'
end


# upload photos
get "/upload" do 
  @user = User.get(session[:userid])
  @albums = User.get(session[:userid]).albums
  haml :'/photos/upload'
end

get "/album/:id/upload" do
  @user = User.get(session[:userid])
  @albums = [Album.get(params[:id])]
  haml :'/photos/upload'  
end

post "/upload" do
  album = Album.get params[:album_id]
  (1..6).each do |i|
    if params["file#{i}"] && (tmpfile = params["file#{i}"][:tempfile]) && (name = params["file#{i}"][:filename])
      Photo.new(:title => name, :album => album, :tmpfile => tmpfile).save
    end
  end
  redirect "/album/#{album.id}"
end

# add annotation
post "/annotation/:photo_id" do
  photo = Photo.get params[:photo_id]
  note = Annotation.create(:x => params["annotation"]["x1"], 
                           :y => params["annotation"]["y1"], 
                           :height => params["annotation"]["height"],
                           :width => params["annotation"]["width"],
                           :description => params["annotation"]["text"])
  photo.annotations << note
  photo.save
  redirect "/photo/#{params[:photo_id]}"
end

# delete annotation
delete "/annotation/:id" do
  note = Annotation.get(params[:id])
  photo = note.photo
  if note.destroy
    redirect "/photo/#{photo.id}"
  else
      throw "Cannot delete this annotation!"
  end
end
