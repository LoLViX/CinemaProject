extends Node

# ============================================================
# TextDB.gd — Autoload de traducciones
# Uso: TextDB.t("movie.godfather.title")  →  "El Padrino"
# ============================================================

const _DB: Dictionary = {
	# --- UI genérico ---
	"ui.counter_ready":       "[E] Atender cliente",
	"ui.serve":               "[E] Servir",
	"ui.continue":            "[E] Continuar",

	# --- Películas: títulos ---
	"movie.alien.title":                                "Alien",
	"movie.back_to_the_future.title":                   "Regreso al Futuro",
	"movie.blade_runner.title":                         "Blade Runner",
	"movie.dark_knight.title":                          "El Caballero Oscuro",
	"movie.die_hard.title":                             "Jungla de Cristal",
	"movie.exorcist.title":                             "El Exorcista",
	"movie.gladiator.title":                            "Gladiator",
	"movie.godfather.title":                            "El Padrino",
	"movie.jaws.title":                                 "Tiburón",
	"movie.jurassic_park.title":                        "Jurassic Park",
	"movie.matrix.title":                               "Matrix",
	"movie.monty_python_and_the_holy_grail.title":      "Los Caballeros de la Mesa Cuadrada",
	"movie.pulp_fiction.title":                         "Pulp Fiction",
	"movie.raiders_of_the_lost_ark.title":              "En Busca del Arca Perdida",
	"movie.seven.title":                                "Seven",
	"movie.shining.title":                              "El Resplandor",
	"movie.silence_of_the_lambs.title":                 "El Silencio de los Corderos",
	"movie.terminator_two.title":                       "Terminator 2",
	"movie.thing.title":                                "La Cosa",
	"movie.two_thousand_and_one_a_space_odyssey.title": "2001: Una Odisea del Espacio",

	# --- Películas: sinopsis ---
	"movie.alien.syn":                                "Una tripulación espacial recibe una señal de socorro y encuentra algo que no debería haber encontrado.",
	"movie.back_to_the_future.syn":                   "Un adolescente viaja al pasado en un DeLorean y pone en peligro su propia existencia.",
	"movie.blade_runner.syn":                         "Un detective caza replicantes en un Los Ángeles cyberpunk del futuro.",
	"movie.dark_knight.syn":                          "Batman se enfrenta al Joker, un criminal que quiere hundir Gotham en el caos.",
	"movie.die_hard.syn":                             "Un policía solo contra un grupo de terroristas en un rascacielos. Yippee-ki-yay.",
	"movie.exorcist.syn":                             "Una niña es poseída por una entidad demoníaca. Dos sacerdotes intentan salvarla.",
	"movie.gladiator.syn":                            "Un general romano es traicionado y convertido en gladiador. La venganza tiene precio.",
	"movie.godfather.syn":                            "La historia de la familia Corleone y el crimen organizado en la América de posguerra.",
	"movie.jaws.syn":                                 "Un gran tiburón blanco aterroriza una pequeña ciudad costera. El sheriff no nada bien.",
	"movie.jurassic_park.syn":                        "Un parque temático con dinosaurios de verdad. Los dinosaurios tienen otras ideas.",
	"movie.matrix.syn":                               "Un hacker descubre que la realidad es una simulación y que él podría ser el elegido.",
	"movie.monty_python_and_the_holy_grail.syn":      "El Rey Arturo y sus caballeros buscan el Santo Grial de la forma más absurda posible.",
	"movie.pulp_fiction.syn":                         "Historias entrecruzadas de criminales, boxeadores y pistoleros en el Los Ángeles de los 90.",
	"movie.raiders_of_the_lost_ark.syn":              "Indiana Jones compite contra los nazis para encontrar el Arca de la Alianza.",
	"movie.seven.syn":                                "Dos detectives persiguen a un asesino que basa sus crímenes en los siete pecados capitales.",
	"movie.shining.syn":                              "Un escritor lleva a su familia a un hotel aislado para el invierno. El hotel tiene planes propios.",
	"movie.silence_of_the_lambs.syn":                 "Una agente del FBI busca a un asesino en serie con la ayuda de otro asesino en serie.",
	"movie.terminator_two.syn":                       "Una máquina asesina del futuro protege al niño al que antes vino a matar.",
	"movie.thing.syn":                                "Una criatura extraterrestre se infiltra en una base antártica imitando a sus víctimas.",
	"movie.two_thousand_and_one_a_space_odyssey.syn": "Un viaje al espacio exterior, la evolución humana y una IA que empieza a tener sus propios planes.",

	# --- Reacciones del cliente ---
	"cust.react_ok.1":   "¡Perfecto, eso es justo lo que buscaba!",
	"cust.react_ok.2":   "Vaya, qué buena elección. Me apunto.",
	"cust.react_ok.3":   "¡Genial! Era lo que tenía en mente.",
	"cust.react_bad.1":  "Mmm… no era exactamente lo que esperaba.",
	"cust.react_bad.2":  "Bueno… supongo que algo es algo.",
	"cust.react_bad.3":  "No es para mí, pero gracias de todas formas.",
	"cust.react_ok.4":   "Justo lo que necesitaba, muchas gracias.",
	"cust.react_bad.4":  "En fin… algo es algo, supongo.",

	# --- Petición de comida ---
	"cust.foodask.1":   "¿Me pones algo para picar?",
	"cust.foodask.2":   "Quiero palomitas y una bebida.",
	"cust.foodask.3":   "Un refresco estaría bien.",
	"cust.foodask.4":   "¿Tienes hotdog? Con mostaza, por favor.",
	"cust.foodask.5":   "Palomitas con mantequilla y una cola.",

	# --- Despedidas ---
	"cust.goodbye.1":   "¡Gracias! Que vaya bien.",
	"cust.goodbye.2":   "Hasta luego.",
	"cust.goodbye.3":   "¡Hasta la próxima!",
	"cust.goodbye.4":   "Buenas noches.",
}

func t(key: String) -> String:
	if _DB.has(key):
		return _DB[key]
	push_warning("TextDB: key no encontrada → \"%s\"" % key)
	return "[%s]" % key
