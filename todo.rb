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
  def sort_todos(list, &block)
    complete_todos, incomplete_todos = list.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  # used to create the identifiers for the todos
  def next_todo_id(todos)
    max = todos.map { |todo| todo[:id] }.max || 0
    max + 1
  end

  # used to create the identifiers for the lists
  def next_list_id(lists)
    max = lists.map { |list| list[:id] }.max || 0
    max + 1
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
  @list = session[:lists].detect { |list| list.value?(@list_id) }

  if @list
    erb :list, layout: :layout
  else
    session[:error] = "The specified list was not found."
    redirect '/lists'
  end
end

# render edit existing todo
get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = session[:lists].detect { |list| list.value?(@list_id) }

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
    list_id = next_list_id(session[:lists])
    session[:lists] << { id: list_id, name: params[:list_name], todos: [] }
    session[:success] = "The list has been created."
    redirect '/lists'
  end
end

# rename a list
post '/edit/:id' do
  list_rename = params[:list_rename].strip
  @list_id = params[:id].to_i
  @list = session[:lists].detect { |list| list.value?(@list_id) }

  if (error = error_for_list_name(list_rename))
    session[:error] = error
    erb :edit, layout: :layout
  else
    @list[:name] = list_rename
    session[:success] = "The list has been renamed."
    redirect "/lists/#{@list[:id]}"
  end
end

# delete list item
post '/lists/delete/:id' do
  @list_id = params[:id].to_i
  @list = session[:lists].detect { |list| list.value?(@list_id) }
  session[:lists].delete(@list)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect '/lists'
  end
end

# delete todo item
post '/lists/:id/todo/delete/:todo_id' do
  @list_id = params[:id].to_i
  @list = session[:lists].detect { |list| list.value?(@list_id) }
  list_todos = @list[:todos]
  todo_id = params[:todo_id].to_i
  todo_item = list_todos.detect { |todo| todo.value?(todo_id) }
  list_todos.delete(todo_item)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{params[:list_id]}"
  end
end

# update todo item
post '/lists/:id/todo/complete/:todo_id' do
  @list_id = params[:id].to_i
  @list = session[:lists].detect { |list| list.value?(@list_id) }
  list_todos = @list[:todos]
  todo_id = params[:todo_id].to_i
  todo_item = list_todos.detect { |todo| todo.value?(todo_id) }
  todo_item[:completed] = params[:completed] == 'true'
  session[:success] = "The todo has been updated."

  redirect "/lists/#{params[:list_id]}"
end

# complete all todo items in a list
post "/lists/:list_id/complete_all" do
  @list_id = params[:id].to_i
  @list = session[:lists].detect { |list| list.value?(@list_id) }
  list_todos = @list[:todos]
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
  @list = session[:lists].detect { |list| list.value?(@list_id) }

  if (error = error_for_todo_name(todo))
    session[:error] = error
    erb :list, layout: :layout
  else
    next_id = next_todo_id(@list[:todos])
    @list[:todos] << { id: next_id, name: todo, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end
