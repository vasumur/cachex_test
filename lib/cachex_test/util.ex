defmodule CachexTest.Util do
  require Logger

  def get_http_options do
    timeout = :timer.minutes(20)

    [
      hackney: [pool: :cachextest_pool],
      connect_timeout: timeout,
      recv_timeout: timeout,
      timeout: timeout
    ]
  end

  def http_get(url), do: http_get(url, [{"content-type", "text/plain"}])

  def http_get(url, headers) do
    Logger.debug("HTTP get to #{url}")

    HTTPoison.get(url, headers, get_http_options())
    |> body_from_http_response(url)
  end

  def http_get_json(url), do: url |> http_get() |> decode_json_body()

  def http_get_json(url, headers) do
    url |> http_get(headers) |> decode_json_body()
  end

  def http_delete(url), do: http_get(url, [{"content-type", "text/plain"}])

  def http_delete(url, headers) do
    Logger.debug("HTTP get to #{url}")

    HTTPoison.delete(url, headers, get_http_options())
    |> body_from_http_response(url)
  end

  def http_delete_json(url), do: url |> http_delete() |> decode_json_body()

  def http_delete_json(url, headers) do
    url |> http_delete(headers) |> decode_json_body()
  end

  def http_post_json(payload, url, headers \\ [{"content-type", "application/json"}]) do
    Logger.debug("HTTP post to #{url} with payload: #{inspect(payload)}")

    payload =
      cond do
        is_binary(payload) ->
          payload

        is_tuple(payload) ->
          payload

        true ->
          Poison.encode!(payload)
      end

    HTTPoison.post(url, payload, headers, get_http_options())
    |> body_from_http_response(url)
    |> decode_json_body
  end

  def http_post_xml(xml, url) do
    h = [{"content-type", "application/xml"}]
    HTTPoison.post(url, xml, h, get_http_options())
  end

  def body_from_http_response(response, url) do
    case response do
      {:ok, %{:status_code => 200, :body => body}} ->
        body

      {:ok, %{:status_code => status_code, :body => body}} ->
        msg = "Error HTTP #{status_code} response " <> "(url = #{url}): #{inspect(body)}"
        Logger.error(msg)
        raise msg

      {:error, %HTTPoison.Error{id: _id, reason: reason}} ->
        msg = "Error in http call " <> "(url = #{url}): #{inspect(reason)}"
        Logger.error(msg)
        raise msg
    end
  end

  def decode_json_body("" = _body) do
    %{}
  end

  def decode_json_body(nil = _body) do
    %{}
  end

  def decode_json_body(body) do
    # Fixes where Json parser fails in elixir for É
    String.replace(body, <<201>>, "E") |> Poison.decode!()
  end

  def clear_cache(cache_name) do
    {:ok, num_keys_cleared} = Cachex.clear(cache_name)
    Logger.info("Cleared #{num_keys_cleared} entries from cache = #{inspect(cache_name)}")
  end

  def refresh_cache(cache_name, key, data, ttl_hrs \\ 1) do
    case Cachex.update(cache_name, key, data, ttl: :timer.hours(ttl_hrs)) do
      {:ok, false} -> put_to_cache(cache_name, key, data, :timer.hours(ttl_hrs))
      {:ok, new_value} -> {:ok, new_value}
    end
  end

  def fetch_load_cache(cache_name, key, fallback_fn) do
    fetch_load_cache(cache_name, key, fallback_fn, nil)
  end

  def fetch_load_cache(cache_name, key, fallback_fn, ttl_time) do
    case Cachex.fetch(cache_name, key, fallback_fn) do
      {:ok, data} ->
        Logger.debug("cache (#{cache_name})  hit for key #{inspect(key)}")
        data

      {:commit, data} ->
        cond do
          data == nil ->
            Logger.info("no data (nil) cached in (#{cache_name}) for key #{inspect(key)}")
            Cachex.del(cache_name, key)
            nil

          is_nil(ttl_time) ->
            Logger.info("loaded cache in (#{cache_name}) for key #{inspect(key)} (indefinte)")
            data

          ttl_time > 0 ->
            Cachex.expire(cache_name, key, ttl_time)
            Logger.info("loaded cache (#{cache_name}) for key #{inspect(key)} (#{ttl_time})")
            data
        end

      {:error, :no_cache} = error ->
        Logger.error(
          "Error #{inspect(error)} Occurred fetching from cache #{inspect(cache_name)} for key = #{inspect(key)} fallback_fn = #{inspect(fallback_fn)}"
        )

        # In a rare case where a cache warmer asks for pbd which is not cached yet (which is done by another warmer)
        # In that case provide the value by executing the fall back function.
        fallback_fn.()

      x ->
        Logger.info("received #{inspect(key)} - #{inspect(x)}")
        x
    end
  end

  def put_to_cache(_cache_name, _key, nil = _data, _ttl) do
    Logger.info("No Cache update as the input data is nil")
    nil
  end

  def put_to_cache(cache_name, key, data, ttl) do
    {:ok, true} = Cachex.put(cache_name, key, data, ttl: ttl)
  end

  def put_to_cache(cache_name, key, data) do
    {:ok, true} = Cachex.put(cache_name, key, data)
  end

  def get_from_cache(cache_name, key) do
    {:ok, data} = Cachex.get(cache_name, key)
    data
  end

  def naivedatetime_now() do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

  def utcdatetime_now() do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  def time_now() do
    DateTime.now!("America/New_York")
  end

  def month_ends(year, month, n, incep_dt, acc) do
    prev_mth_end =
      Timex.end_of_month(year, month)
      |> Timex.shift(months: -1)
      |> Timex.end_of_month()

    cond do
      n <= 0 ->
        acc

      Timex.before?(prev_mth_end, incep_dt) ->
        acc

      true ->
        month_ends(prev_mth_end.year, prev_mth_end.month, n - 1, incep_dt, [prev_mth_end | acc])
    end
  end

  def common_cache() do
    :common
  end

  def security_cache() do
    :security
  end

  def get_pbd() do
    k = :pbd
    f = fn -> fetch_pbd(k) end

    fetch_load_cache(common_cache(), k, f, :timer.hours(1))
  end

  def fetch_pbd(:pbd) do
    read_resource("pbd_date.exs")
  end

  def get_data() do
    k = get_pbd()
    f = fn -> fetch_data(k) end

    fetch_load_cache(common_cache(), k, f, :timer.hours(1))
  end

  def fetch_data(date) do
    x =
      read_resource("data_by_date.exs")
      |> case do
        nil -> nil
        data -> Map.get(data, date)
      end

    load_security_data_into_cache(x)
    x
  end

  def load_security_data_into_cache(data) do
    security_data = data |> Enum.map(fn {k, v} -> {k, v} end)

    {:ok, true} =
      Cachex.put_many(
        security_cache(),
        security_data
      )
  end

  def parse_date_yyyy_mm_dd(date_str) do
    date_str |> Timex.parse!("{YYYY}-{M}-{D}") |> Timex.to_date()
  end

  def read_resource(file_nm), do: (resource_dir() <> file_nm) |> Code.eval_file() |> elem(0)
  def read_json_resource(file_nm), do: File.read!(resource_dir() <> file_nm) |> Poison.decode!()
  def resource_dir, do: Application.app_dir(:cachex_test, "priv/resources") <> "/"

  def get_it_delimeted(vals, delimeter \\ ",", to_string_fn \\ nil) when is_list(vals) do
    case to_string_fn do
      nil ->
        vals |> Enum.uniq() |> Enum.join(delimeter)

      tos_fn ->
        vals |> Enum.uniq() |> (Enum.map(fn val -> tos_fn.(val) end) |> Enum.join(delimeter))
    end
  end

  def get_it_split(vals, delimeter \\ ",")

  def get_it_split(nil, _delimeter) do
    nil
  end

  def get_it_split(vals, delimeter) when is_binary(vals) do
    vals |> String.split(delimeter)
  end
end
