import { isHostVisible } from "c/hostVisibility";

describe("hostVisibility", () => {
  it("givenHostWithOneClientRect_whenChecked_thenVisible", () => {
    // Arrange
    const host = { getClientRects: () => [{}] };

    // Act
    const result = isHostVisible(host);

    // Assert
    expect(result).toBe(true);
  });

  it("givenHostWithNoClientRect_whenChecked_thenHidden", () => {
    // Arrange
    const host = { getClientRects: () => [] };

    // Act
    const result = isHostVisible(host);

    // Assert
    expect(result).toBe(false);
  });
});
