defmodule CachexTestWeb.PageController do
  use CachexTestWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
