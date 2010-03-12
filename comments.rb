put "/comment/:class/:id" do
  return unless %w(status activity post photo page).include? params[:class]
  clazz = Kernel.const_get(params[:class].capitalize)
  item = clazz.get params[:id]
  Comment.create(:text => params[:text], params[:class].to_sym => item, :user => @user)
  redirect params[:return_url]
end