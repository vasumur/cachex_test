defmodule CachexTest.Warmers.DataWarmer do
  require Logger
  use Cachex.Warmer
  alias CachexTest.Util

  def interval() do
    :timer.hours(2)
  end

  def execute(_connection) do
    Logger.info("Started Loading Data Into Cache")
    date = Util.get_pbd()

    ret =
      try do
        {:ok, [{date, Util.fetch_data(date)}]}
      rescue
        error ->
          Logger.error("Error While Warming Data - #{inspect(error)}")
          Logger.error(Exception.format(:error, error, __STACKTRACE__))

          :ignore
      end

    Logger.info("Completed Loading Data Into Cache")
    ret
  end
end
