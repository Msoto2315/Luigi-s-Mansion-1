shader_type canvas_item;

// Velocidad de movimiento del fuego
uniform vec2 scroll_speed = vec2(0.2, 0.0); 

void fragment() {
    // Tomamos las coordenadas UV y les sumamos el tiempo multiplicado por la velocidad
    vec2 moving_uv = UV + (TIME * scroll_speed);
    
    // Usamos texture() para pintar, con el parámetro repeat activo en la textura
    COLOR = texture(TEXTURE, moving_uv);
}