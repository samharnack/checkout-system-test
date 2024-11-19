defmodule Checkout.Cart do
  alias Checkout.Product
  alias Checkout.Discount
  alias Checkout.LineItem

  @moduledoc """
  A cart holds products with their quantities and can apply discounts through a discount resolver
  that is called with the cart's products and quantities allowing for a single lookup instead of an
  N+1 lookup.
  """

  @type t :: %__MODULE__{
          products: %{Product.t() => pos_integer()},
          discount_resolver: (map() -> map()) | nil
        }

  defstruct products: %{}, discount_resolver: nil

  @doc """
  Creates a new cart with optional configuration.

  ## Options
    * `:discount_resolver` - A function that takes a list of {product, quantity} tuples
      and returns a map of applicable discounts. Defaults to `nil`.

  ## Examples
      iex> Cart.new()
      %Cart{products: %{}, discount_resolver: nil}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    opts =
      Keyword.validate!(opts,
        discount_resolver: nil
      )

    struct!(__MODULE__, opts)
  end

  @doc """
  Adds a product to the cart. If the product already exists, increments its quantity by the
  specified amount (default 1).

  ## Examples
      iex> cart = Cart.new()
      iex> product = %Product{id: "PRODUCT1", name: "Product 1", price_in_cents: 1000}
      iex> %Cart{products: %{^product => 1}} = Cart.add_product(cart, product)
  """
  @spec add_product(t(), Product.t(), pos_integer()) :: t()
  def add_product(%__MODULE__{products: products} = cart, %Product{} = product, quantity \\ 1) do
    %{cart | products: Map.update(products, product, quantity, &(&1 + quantity))}
  end

  @doc """
  Returns a list of line items for all products in the cart, with discounts applied.
  The discount_resolver is used to batch lookup discounts for all products in the cart.

  ## Examples
      iex> cart = Cart.new()
      iex> Cart.list_line_items(cart)
      []
  """
  @spec list_line_items(t()) :: [LineItem.t()]
  def list_line_items(%__MODULE__{} = cart) do
    discounts = resolve_discounts(cart)

    Enum.map(cart.products, fn {product, quantity} ->
      discounts = Map.get(discounts, {product, quantity}, [])

      get_line_item(product, quantity, discounts)
    end)
  end

  @doc """
  Calculates the total price of all items in the cart, including any discounts.

  ## Examples
      iex> cart = Cart.new()
      iex> Cart.calculate_total(cart)
      0
  """
  @spec calculate_total(t()) :: non_neg_integer()
  def calculate_total(%__MODULE__{} = cart) do
    line_items = list_line_items(cart)

    Enum.reduce(line_items, 0, &(&1.total + &2))
  end

  @spec get_line_item(Product.t(), pos_integer(), map()) :: LineItem.t()
  defp get_line_item(%Product{} = product, quantity, discounts)
       when is_number(quantity) and is_list(discounts) do
    line_item = LineItem.build(product, quantity)

    Enum.reduce(discounts, line_item, &Discount.apply_discount(&1, &2))
  end

  @spec resolve_discounts(t()) :: map()
  defp resolve_discounts(%__MODULE__{} = cart) when is_function(cart.discount_resolver, 1) do
    cart.products |> Enum.into([]) |> cart.discount_resolver.()
  end

  defp resolve_discounts(_cart), do: %{}
end
