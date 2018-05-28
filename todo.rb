require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do # tell Sinatra to use sessions
  enable :sessions # activate sessions support
  set :session_secret, 'secret' # setting secret to 'secret'..don't do this
  set :erb, :escape_html => true # HTML escape (sanitize) input
end

helpers do
  def completed?(list)
    todos_remaining_count(list).zero? && todos_size(list) > 0
  end

  def classify_complete_list(list)
    "complete" if completed?(list)
  end

  def classify_complete_todo(todo)
    "complete" if todo[:completed]
  end

  def todos_size(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].reject { |todo| todo[:completed] }.size
  end

  def todos_total(list)
    "#{todos_remaining_count(list)}/#{todos_size(list)}"
  end

  def sorted_with_original_index(lists)
    sorted_lists = lists.sort_by { |list| completed?(list) ? 1 : 0 }
    sorted_lists.each do |sorted_list|
      yield(sorted_list, lists.index(sorted_list))
    end
  end

  # will do the sorting for the todos with the algorithm in the walkthrough
  def sort_todos(list)
    complete_todos, incomplete_todos = list.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield(todo, list.index(todo)) }
    complete_todos.each { |todo| yield(todo, list.index(todo)) }
  end
end

get '/' do
  redirect '/lists'
end

before do
  session[:lists] ||= []
end

# view list of lists
get "/lists" do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# view individual list item
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  if @list
    erb :list, layout: :layout
  else
    session[:error] = "The specified list was not found."
    redirect '/lists'
  end
end

# render edit existing todo
get '/lists/:id/edit' do
  @list = session[:lists][params[:id].to_i]

  erb :edit, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo_name(name)
  "Todo must be between 1 and 100 characters." unless (1..100).cover? name.size
end

# create a new list
post '/lists' do
  list_name = params[:list_name].strip

  if (error = error_for_list_name(list_name))
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: params[:list_name], todos: [] }
    session[:success] = "The list has been created."
    redirect '/lists'
  end
end

# rename a list
post '/edit/:id' do
  list_rename = params[:list_rename].strip
  list_index = params[:id].to_i
  @list = session[:lists][list_index]

  if (error = error_for_list_name(list_rename))
    session[:error] = error
    erb :edit, layout: :layout
  else
    session[:lists][list_index][:name] = list_rename
    session[:success] = "The list has been renamed."
    redirect "/lists/#{list_index}"
  end
end

# delete list item
post '/lists/delete/:id' do
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted."

  redirect '/lists'
end

# delete todo item
post '/lists/:list_id/todo/delete/:todo_id' do
  list_todos = session[:lists][params[:list_id].to_i][:todos]
  todo_id = params[:todo_id].to_i
  list_todos.delete_at(todo_id)
  session[:success] = "The todo has been deleted."

  redirect "/lists/#{params[:list_id]}"
end

# update todo item
post '/lists/:list_id/todo/complete/:todo_id' do
  list_todos = session[:lists][params[:list_id].to_i][:todos]
  todo_id = params[:todo_id].to_i
  todo =  list_todos[todo_id]
  todo[:completed] = params[:completed] == 'true'
  session[:success] = "The todo has been updated."

  redirect "/lists/#{params[:list_id]}"
end

# complete all todo items in a list
post "/lists/:list_id/complete_all" do
  list_id = params[:list_id].to_i
  list_todos = session[:lists][list_id][:todos]
  list_todos.each do |todo|
    todo[:completed] = true
  end
  session[:success] = "All todos have been completed."

  redirect "/lists/#{list_id}"
end

# add a todo item to a list
post '/lists/:id/todos' do
  todo = params[:todo].strip
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  if (error = error_for_todo_name(todo))
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end
